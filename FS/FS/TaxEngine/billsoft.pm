package FS::TaxEngine::billsoft;

use strict;
use vars qw( $DEBUG $TIMEOUT %TAX_CLASSES );
use base 'FS::TaxEngine';
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbh);
use FS::part_pkg;
use FS::cdr;
use FS::upload_target;
use Date::Format qw( time2str );
use File::chdir;
use File::Copy qw(move);
use Text::CSV_XS;
use Locale::Country qw(country_code2code);

# "use constant" this, for performance?
our @input_cols = qw(
  RequestType
  BillToCountryISO
  BillToZipCode
  BillToZipP4
  BillToPCode
  BillToNpaNxx
  OriginationCountryISO
  OriginationZipCode
  OriginationZipP4
  OriginationNpaNxx
  TerminationCountryISO
  TerminationZipCode
  TerminationZipP4
  TerminationPCode
  TerminationNpaNxx
  TransactionType
  ServiceType
  Date
  Charge
  CustomerType
  Lines
  Sale
  Regulated
  Minutes
  Debit
  ServiceClass
  Lifeline
  Facilities
  Franchise
  BusinessClass
  CompanyIdentifier
  CustomerNumber
  InvoiceNumber
  DiscountType
  ExemptionType
  AdjustmentMethod
  Optional
);

$DEBUG = 2;

$TIMEOUT = 86400; # absolute time limit on waiting for a response file.

FS::UID->install_callback(\&load_tax_classes);

sub info {
  { batch => 1,
    override => 0,
    manual_tax_location => 1,
  },
}

sub add_sale { } #do nothing

sub spooldir {
  $FS::UID::cache_dir . "/Billsoft";
}

sub spoolname {
  my $self = shift;
  my $spooldir = $self->spooldir;
  mkdir $spooldir, 0700 unless -d $spooldir;
  my $upload = $self->spooldir . '/upload';
  mkdir $upload, 0700 unless -d $upload;
  my $basename = $self->conf->config('billsoft-company_code') .
                 time2str('%Y%m%d', time); # use the real clock time here
  my $uniq = 'AA';
  while ( -e "$upload/$basename$uniq.CSV" ) {
    $uniq++;
    # these two letters must be unique within each day
  }
  "$basename$uniq.CSV";
}

=item part_pkg_taxproduct PART_PKG, CLASSNUM

Returns the taxproduct string (T-code and S-code concatenated) for
PART_PKG with usage class CLASSNUM. CLASSNUM can be a numeric classnum,
an empty string (for the package's base taxproduct), 'setup', or 'recur'.

Returns undef if the package doesn't have a taxproduct.

=cut

sub part_pkg_taxproduct {
  my ($self, $part_pkg, $classnum) = @_;
  my $pkgpart = $part_pkg->get('pkgpart');
  # all taxproducts
  $self->{_taxproduct} ||= {};
  # taxproduct(s) that are relevant to this package
  my $pkg_taxproduct = $self->{_taxproduct}{$pkgpart} ||= {};
  my $taxproduct; # return this
  $classnum ||= '';
  if (exists($pkg_taxproduct->{$classnum})) {
    $taxproduct = $pkg_taxproduct->{$classnum};
  } else {
    my $part_pkg_taxproduct = $part_pkg->taxproduct($classnum);
    $taxproduct = $pkg_taxproduct->{$classnum} = (
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : undef
    );
    if (!$taxproduct) {
      $self->log->error("part_pkg $pkgpart, class $_: taxproduct not found");
      if ( !$self->conf->exists('ignore_incalculable_taxes') ) {
        die "part_pkg $pkgpart, class $_: taxproduct not found\n";
      }
    }
  }
  warn "part_pkg $pkgpart, class $classnum: ".
    ($taxproduct ?
      "using taxproduct $taxproduct\n" :
      "taxproduct not found\n")
    if $DEBUG;
  return $taxproduct;
}

sub log {
  my $self = shift;
  return $self->{_log} ||= FS::Log->new('FS::TaxEngine::billsoft');
}

sub conf {
  my $self = shift;
  return $self->{_conf} ||= FS::Conf->new;
}

sub create_batch {
  my ($self, %opt) = @_;

  my @invoices = qsearch('cust_bill', { pending => 'Y' });
  $self->log->info(scalar(@invoices)." pending invoice(s) found.");
  return if @invoices == 0;

  $DB::single=1; # XXX

  my $spooldir = $self->spooldir;
  my $spoolname = $self->spoolname;
  my $fh = IO::File->new();
  $self->log->info("Starting batch in $spooldir/upload/$spoolname");
  $fh->open("$spooldir/upload/$spoolname", '>');
  $self->{fh} = $fh;

  my $csv = Text::CSV_XS->new({ binary => 1, eol => "\r\n" });
  $csv->print($fh, \@input_cols);
  $csv->column_names(\@input_cols);

  # XXX limit based on freeside-daily custnum/agentnum options
  # and maybe invoice date
  foreach my $cust_bill (@invoices) {

    my $invnum = $cust_bill->invnum;
    my $cust_main = $cust_bill->cust_main;
    my $cust_type = $cust_main->taxstatus;
    my $invoice_date = time2str('%Y%m%d', $cust_bill->_date);

    my %bill_to = do {
      my $location = $cust_main->bill_location;
      my $zip = $location->zip;
      my $plus4 = '';
      if ($location->country eq 'US') {
        ($zip, $plus4) = split(/-/, $zip);
      }
      ( BillToCountryISO  => uc(country_code2code($location->country,
                                                  'alpha-2' => 'alpha-3')),
        BillToPCode       => $location->geocode,
        BillToZipCode     => $zip,
        BillToZipP4       => $plus4,
      )
    };

    # cache some things
    my (%cust_pkg, %part_pkg, %cust_location, %classname);
    # keys are transaction codes (the first part of the taxproduct string)
    my %all_tcodes;

    my @options = $self->conf->config('billsoft-taxconfig');
    
    my %bill_properties = (
      %bill_to,
      Date              => $invoice_date,
      CustomerType      => $cust_type,
      CustomerNumber    => $cust_bill->custnum,
      InvoiceNumber     => $invnum,
      Facilities        => ($options[0] || ''),
      Franchise         => ($options[1] || ''),
      Regulated         => ($options[2] || ''),
      BusinessClass     => ($options[3] || ''),
    );

    foreach my $cust_bill_pkg ( $cust_bill->cust_bill_pkg ) {
      my $cust_pkg = $cust_pkg{$cust_bill_pkg->pkgnum}
                 ||= $cust_bill_pkg->cust_pkg;
      my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;
      my $part_pkg = $part_pkg{$pkgpart} ||= FS::part_pkg->by_key($pkgpart);
      my $resale_mode = ($part_pkg->option('wholesale',1) ? 'Resale' : 'Sale');
      my %pkg_properties = (
        %bill_properties,
        Sale              => $resale_mode,
        Optional          => $cust_bill_pkg->billpkgnum, # will be echoed
        # others at this level? Lifeline?
        # DiscountType may be relevant...
        # and Proration
      );

      my $usage_total = 0;

      # cursorized joined search on the invoice details, for memory efficiency
      my $cdr_search = FS::Cursor->new({
        'table'     => 'cdr',
        'hashref'   => { freesidestatus => 'done' },
        'addl_from' => ' JOIN cust_bill_pkg_detail USING (detailnum)',
        'extra_sql' => "AND cust_bill_pkg_detail.billpkgnum = ".
                       $cust_bill_pkg->billpkgnum
      });

      while (my $cdr = $cdr_search->fetch) {
        my $classnum = $cdr->rated_classnum;
        if ( $classnum ) {
          $classname{$classnum} ||= FS::usage_class->by_key($classnum)->classname;
        }

        my $taxproduct = $self->part_pkg_taxproduct($part_pkg, $classnum)
          or next;
        my ($tcode, $scode) = split(':', $taxproduct);

        # For CDRs, use the call termination site rather than setting
        # Termination fields to the service address.
        $csv->print_hr($fh, {
          %pkg_properties,
          RequestType       => 'CalcTaxes',
          OriginationNpaNxx => substr($cdr->src_lrn || $cdr->src, 0, 6),
          TerminationNpaNxx => substr($cdr->dst_lrn || $cdr->dst, 0, 6),
          TransactionType   => $tcode,
          ServiceType       => $scode,
          Charge            => $cdr->rated_price,
          Minutes           => ($cdr->duration / 60.0), # floating point
        });

        $usage_total += $cdr->rated_price;

      } # while $cdr = $cdr_search->fetch
      
      my $locationnum = $cust_pkg->locationnum;

      # use termination address for the service location
      my %termination = do {
        my $location = $cust_location{$locationnum} ||= $cust_pkg->cust_location;
        my $zip = $location->zip;
        my $plus4 = '';
        if ($location->country eq 'US') {
          ($zip, $plus4) = split(/-/, $zip);
        }
        ( TerminationCountryISO  => uc(country_code2code($location->country,
                                                        'alpha-2' => 'alpha-3')),
          TerminationPCode       => $location->geocode,
          TerminationZipCode     => $zip,
          TerminationZipP4       => $plus4,
        )
      };

      foreach (qw(setup recur)) {
        my $taxproduct = $self->part_pkg_taxproduct($part_pkg, $_);
        next unless $taxproduct;

        my ($tcode, $scode) = split(':', $taxproduct);
        $all_tcodes{$tcode} ||= 1;

        my $price = $cust_bill_pkg->get($_);

        $price -= $usage_total if $_ eq 'recur';

        $csv->print_hr($fh, {
            %pkg_properties,
            %termination,
            RequestType       => 'CalcTaxes',
            TransactionType   => $tcode,
            ServiceType       => $scode,
            Charge            => $price,
        } );

      } # foreach (setup, recur)

      # taxes based on number of lines (E911, mostly)
      # mostly S-code 21 but can be others, as they want to know about
      # Centrex trunks, PBX extensions, etc.
      #
      # (note: the nomenclature of "service" and "transaction" codes is 
      # backward from the way most people would use the terms.  you'd think
      # that in "cellular activation", "cellular" would be the service and 
      # "activation" would be the transaction, but for Billsoft it's the 
      # reverse.  I recommend calling them "S" and "T" codes internally just 
      # to avoid confusion.)

      # XXX cache me
      if ( my $lines_taxproduct = $part_pkg->units_taxproduct ) {
        my $lines = $cust_bill_pkg->units;
        my $taxproduct = $lines_taxproduct->taxproduct;
        my ($tcode, $scode) = split(':', $taxproduct);
        $all_tcodes{$tcode} ||= 1;
        if ( $lines ) {
          $csv->print_hr($fh, {
            %pkg_properties,
            %termination,
            RequestType       => 'CalcTaxes',
            TransactionType   => $tcode,
            ServiceType       => $scode,
            Charge            => 0,
            Lines             => $lines,
          } );
        }
      }

    } # foreach my $cust_bill_pkg

    foreach my $tcode (keys %all_tcodes) {

      # S-code 43: per-invoice tax
      # XXX not exactly correct; there's "Invoice Bundle" (7:94) and
      # "Centrex Invoice" (7:623). Local Exchange service would benefit from
      # more high-level selection of the tax properties. (Infer from the FCC
      # reporting options?)
      my $invoice_taxproduct = FS::part_pkg_taxproduct->count(
        'data_vendor = \'billsoft\' and taxproduct = ?',
        $tcode . ':43'
      );
      if ( $invoice_taxproduct ) {
        $csv->print_hr($fh, {
          RequestType       => 'CalcTaxes',
          %bill_properties,
          TransactionType   => $tcode,
          ServiceType       => 43,
          Charge            => 0,
        } );
      }
    } # foreach $tcode
  } # foreach $cust_bill

  $fh->close;
  return $spoolname;
}

sub cust_tax_locations {
  my $class = shift;
  my $location = shift;
  if (ref $location eq 'HASH') {
    $location = FS::cust_location->new($location);
  }
  my $zip = $location->zip;
  return () unless $location->country eq 'US';
  return () unless $zip;
  # currently the only one supported
  if ( $zip =~ /^(\d{5})(-\d{4})?$/ ) {
    $zip = $1;
  } else {
    die "bad zip code $zip";
  }
  return qsearch({
      table     => 'cust_tax_location',
      hashref   => { 'data_vendor' => 'billsoft' },
      extra_sql => " AND ziplo <= '$zip' and ziphi >= '$zip'",
      order_by  => ' ORDER BY default_location',
  });
}

sub transfer_batch {
  my ($self, %opt) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  eval "use Net::FTP;";
  # set up directories if they're not already
  mkdir $self->spooldir unless -d $self->spooldir;
  local $CWD = $self->spooldir;
  foreach (qw(upload download)) {
    mkdir $_ unless -d $_;
  }
  my $target = qsearchs('upload_target', { hostname => 'ftp.billsoft.com' })
    or die "No Billsoft upload target defined.\n";

  local $CWD = $self->spooldir . '/upload';
  # create the batch
  my $upload = $self->create_batch(%opt); # name of the CSV file
  # returns undef if there were no pending invoices; in that case
  # skip the rest of this procedure
  return if !$upload;

  # upload it
  my $ftp = $target->connect;
  if (!ref $ftp) { # it's an error message
    die "Error connecting to Billsoft FTP server:\n$ftp\n";
  }
  my $fh = IO::File->new();
  $self->log->info("Processing: $upload");
  if ( stat('FTP.ZIP') ) {
    unlink('FTP.ZIP') or die "Failed to remove old tax batch:\n$!\n";
  }
  my $error = system("zip -j -o FTP.ZIP $upload");
  die "Failed to compress tax batch\n$!\n" if $error;
  $self->log->debug("Uploading file");
  $ftp->put('FTP.ZIP');
  unlink('FTP.ZIP');

  local $CWD = $self->spooldir;
  my $download = $upload;
  # naming convention for these is: same as the CSV contained in the 
  # zip file, but with an "R" inserted after the company ID prefix
  $download =~ s/^(...)(\d{8}..).CSV/$1R$2.ZIP/;
  $self->log->debug("Waiting for output file ($download)");
  my $starttime = time;
  my $downloaded = 0;
  while ( time - $starttime < $TIMEOUT ) {
    my @ls = $ftp->ls($download);
    if ( @ls ) {
      if ($ftp->get($download, "download/$download")) {
        $self->log->debug("Downloaded '$download'");
        $downloaded = 1;
        last;
      } else {
        $self->log->warn("Failed to download '$download': ".$ftp->message);
        # We know the file exists, so continue trying to download it.
        # Maybe the problem will get fixed.
      }
    }
    sleep 30;
  }
  if (!$downloaded) {
    $self->log->error("No output file received.");
    next BATCH;
  }
  $self->log->debug("Decompressing...");
  system("unzip -o download/$download");
  my $output = $upload;
  $output =~ s/.CSV$/_dtl.rpt.csv/i;
  if ([ -f $output ]) {
    $self->log->info("Processing '$output'");
    $fh->open($output, '<') or die "failed to open downloaded file $output";
    $self->batch_import($fh); # dies on error
    $fh->close;
    unlink $output unless $DEBUG;
  }
  unlink 'FTP.ZIP';
  $dbh->commit if $oldAutoCommit;
  return;
}

sub batch_import {
  $DB::single = 1; # XXX
  # the hard part
  my ($self, $fh) = @_;
  $self->{'custnums'} = {};
  $self->{'cust_bill'} = {};

  # gather up pending invoices
  foreach my $cust_bill (qsearch('cust_bill', { pending => 'Y' })) {
    $self->{'cust_bill'}{ $cust_bill->invnum } = $cust_bill;
  }

  my $href;
  my $parser = Text::CSV_XS->new({binary => 1});
  # set column names from header row
  $parser->column_names($parser->getline($fh));

  # start parsing the file
  my $errors = 0;
  my $row = 1;
  # the file is functionally a left join of submitted line items with their
  # taxes; if a line item has no taxes then it will produce an output row
  # with all the tax fields empty.
  while ($href = $parser->getline_hr($fh)) {
    next if $href->{TaxTypeID} eq ''; # then this row has no taxes
    next if $href->{TaxAmount} == 0; # then the calculated tax is zero

    my $billpkgnum = $href->{Optional};
    my $invnum = $href->{InvoiceNumber};
    my $cust_bill_pkg; # the line item that this tax applies to
    if ( !exists($self->{cust_bill}->{$invnum}) ) {
      $self->log->error("invoice #$invnum invoice not in pending state");
      $errors++;
      next;
    }
    if ( $billpkgnum ) {
      $cust_bill_pkg = FS::cust_bill_pkg->by_key($billpkgnum);
      if ( $cust_bill_pkg->invnum != $invnum ) {
        $self->log->error("invoice #$invnum invoice number mismatch");
        $errors++;
        next;
      }
    } else {
      $cust_bill_pkg = ($self->{cust_bill}->{$invnum}->cust_bill_pkg)[0];
      $billpkgnum = $cust_bill_pkg->billpkgnum;
    }

    # resolve the tax definition
    # base name of the tax type (like "Sales Tax" or "Universal Lifeline 
    # Telephone Service Charge").
    my $tax_class = $TAX_CLASSES{ $href->{TaxTypeID} };
    if (!$tax_class) {
      $self->log->warn("Unknown tax type $href->{TaxTypeID}");
      $tax_class = FS::tax_class->new({
        'data_vendor' => 'billsoft',
        'taxclass'    => $href->{TaxTypeID},
        'description' => $href->{TaxType}
      });
      my $error = $tax_class->insert;
      if ($error) {
        $self->log->error("Failed to insert tax_class record: $error");
        $errors++;
        next;
      }
      $TAX_CLASSES{ $href->{TaxTypeID} } = $tax_class;
    }
    my $itemdesc = uc($tax_class->description);
    my $location = qsearchs('tax_rate_location', {
                             data_vendor  => 'billsoft',
                             disabled     => '',
                             geocode      => $href->{PCode}
                           });
    if (!$location) {
      $location = FS::tax_rate_location->new({
        'data_vendor' => 'billsoft',
        'geocode'     => $href->{PCode},
        'country'     => uc(country_code2code($href->{CountryISO},
                                              'alpha-3' => 'alpha-2')),
        'state'       => $href->{State},
        'county'      => $href->{County},
        'city'        => $href->{Locality},
      });
      my $error = $location->insert;
      if ($error) {
        $self->log->error("Failed to insert tax_class record: $error");
        $errors++;
        next;
      }
    }
    # jurisdiction name
    my $prefix = '';
    if ( $href->{TaxLevelID} == 0 ) { # national-level tax
      # do nothing
    } elsif ( $href->{TaxLevelID} == 1 ) {
      $prefix = $location->state;
    } elsif ( $href->{TaxLevelID} == 2 ) {
      $prefix = $location->county . ' COUNTY';
    } elsif ( $href->{TaxLevelID} == 3 ) {
      $prefix = $location->city;
    } elsif ( $href->{TaxLevelID} == 4 ) { # unincorporated area ta
      # do nothing
    }
    # Some itemdescs start with the jurisdiction name; otherwise, prepend 
    # it.
    if ( $itemdesc !~ /^(city of )?$prefix\b/i ) {
      $itemdesc = "$prefix $itemdesc";
    }
    # Create or locate a tax_rate record, because we need one to foreign-key
    # the cust_bill_pkg_tax_rate_location record.
    my $tax_rate = $self->find_or_insert_tax_rate(
      geocode     => $href->{PCode},
      taxclassnum => $tax_class->taxclassnum,
      taxname     => $itemdesc,
    );
    my $amount = sprintf('%.2f', $href->{TaxAmount});
    # and add it to the tax under this name
    my $tax_item = $self->add_tax_item(
      invnum      => $invnum,
      itemdesc    => $itemdesc,
      amount      => $amount,
    );
    # and link that tax line item to the taxed sale
    my $subitem = FS::cust_bill_pkg_tax_rate_location->new({
        billpkgnum          => $tax_item->billpkgnum,
        taxnum              => $tax_rate->taxnum,
        taxtype             => 'FS::tax_rate',
        taxratelocationnum  => $location->taxratelocationnum,
        amount              => $amount,
        taxable_billpkgnum  => $billpkgnum,
    });
    my $error = $subitem->insert;
    die "Error linking tax to taxable item: $error\n" if $error;

    $row++;
  } #foreach $line
  if ( $errors > 0 ) {
    die "Encountered $errors error(s); rolling back tax import.\n";
  }

  # remove pending flag from invoices and schedule collect jobs
  foreach my $cust_bill (values %{ $self->{'cust_bill'} }) {
    my $invnum = $cust_bill->invnum;
    $cust_bill->set('pending' => '');
    my $error = $cust_bill->replace;
    die "Error updating invoice #$invnum: $error\n"
      if $error;
    $self->{'custnums'}->{ $cust_bill->custnum } = 1;
  }

  foreach my $custnum ( keys %{ $self->{'custnums'} } ) {
    my $queue = FS::queue->new({ 'job' => 'FS::cust_main::queued_collect' });
    my $error = $queue->insert('custnum' => $custnum);
    die "Error scheduling collection for customer #$custnum: $error\n" 
      if $error;
  }

  '';
}


sub find_or_insert_tax_rate {
  my ($self, %hash) = @_;
  $hash{'tax'} = 0;
  $hash{'data_vendor'} = 'billsoft';
  my $tax_rate = qsearchs('tax_rate', \%hash);
  if (!$tax_rate) {
    $tax_rate = FS::tax_rate->new(\%hash);
    my $error = $tax_rate->insert;
    die "Error inserting tax definition: $error\n" if $error;
  }
  return $tax_rate;
}


sub add_tax_item {
  my ($self, %hash) = @_;
  $hash{'pkgnum'} = 0;
  my $amount = delete $hash{'amount'};
  
  my $tax_item = qsearchs('cust_bill_pkg', \%hash);
  if (!$tax_item) {
    $tax_item = FS::cust_bill_pkg->new(\%hash);
    $tax_item->set('setup', $amount);
    my $error = $tax_item->insert;
    die "Error inserting tax: $error\n" if $error;
  } else {
    $tax_item->set('setup', $tax_item->get('setup') + $amount);
    my $error = $tax_item->replace;
    die "Error incrementing tax: $error\n" if $error;
  }

  my $cust_bill = $self->{'cust_bill'}->{$tax_item->invnum}
    or die "Invoice #".$tax_item->{invnum}." is not pending.\n";
  $cust_bill->set('charged' => 
                  sprintf('%.2f', $cust_bill->get('charged') + $amount));
  # don't replace the record yet, we'll do that at the end

  $tax_item;
}

sub load_tax_classes {
  %TAX_CLASSES = map { $_->taxclass => $_ }
                 qsearch('tax_class', { data_vendor => 'billsoft' });
}


1;
