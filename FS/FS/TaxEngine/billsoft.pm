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
use Parse::FixedLength;

$DEBUG = 1;

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
  my $conf = FS::Conf->new;;
  my $spooldir = $self->spooldir;
  mkdir $spooldir, 0700 unless -d $spooldir;
  my $basename = $conf->config('billsoft-company_code') .
                 time2str('%Y%m%d', time); # use the real clock time here
  my $uniq = 'AA';
  while ( -e "$spooldir/$basename$uniq.CDF" ) {
    $uniq++;
    # these two letters must be unique within each day
  }
  "$basename$uniq.CDF";
}

my $format =
  '%10s' . # Origination
  '%1s'   . # Origination Flag (NPA-NXX)
  '%10s' . # Termination
  '%1s'   . # Termination Flag (NPA-NXX)
  '%10s' . # Service Location
  '%1s'   . # Service Location Flag (Pcode)
  '%1s'   . # Customer Type ('B'usiness or 'R'esidential)
  '%8s'   . # Invoice Date
  '+'     . # Taxable Amount Sign
  '%011d' . # Taxable Amount (5 decimal places)
  '%6d'  . # Lines
  '%6d'  . # Locations
  '%12s'  . # Transaction Type + Service Type
  '%1s'   . # Client Resale Flag ('S'ale or 'R'esale)
  '%1s'   . # Inc-Code ('I'n an incorporated city, or 'O'utside)
  '    '  . # Fed/State/County/Local Exempt
  '%1s'   . # Primary Output Key, flag (our field)
  '%019d' . # Primary Output Key, numeric (our field)
  'R'     . # 'R'egulated (or 'U'nregulated)
  '%011d' . # Call Duration (tenths of minutes)
  'C'     . # Telecom Type ('C'alls, other things)
  '%1s'   . # Service Class ('L'ocal, Long 'D'istance)
  ' NNC'  . # non-lifeline, non-facilities based,
            # non-franchise, CLEC
            # (gross assumptions, may need a config option
  "\r\n";   # at least that's what was in the samples


sub create_batch {
  my ($self, %opt) = @_;

  $DB::single=1; # XXX

  my $spooldir = $self->spooldir;
  my $spoolname = $self->spoolname;
  my $fh = IO::File->new();
  $fh->open("$spooldir/$spoolname", '>>');
  $self->{fh} = $fh;

  # XXX limit based on freeside-daily custnum/agentnum options
  # and maybe invoice date
  my @invoices = qsearch('cust_bill', { pending => 'Y' });
  warn scalar(@invoices)." pending invoice(s) found.\n";
  foreach my $cust_bill (@invoices) {

    my $invnum = $cust_bill->invnum;
    my $cust_main = $cust_bill->cust_main;
    my $cust_type = $cust_main->company ? 'B' : 'R';
    my $invoice_date = time2str('%Y%m%d', $cust_bill->_date);

    # cache some things
    my (%cust_pkg, %part_pkg, %cust_location, %classname);
    # keys are transaction codes (the first part of the taxproduct string)
    # and then locationnums; for per-location taxes
    my %sales;

    foreach my $cust_bill_pkg ( $cust_bill->cust_bill_pkg ) {
      my $cust_pkg = $cust_pkg{$cust_bill_pkg->pkgnum}
                 ||= $cust_bill_pkg->cust_pkg;
      my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;
      my $part_pkg = $part_pkg{$pkgpart} ||= FS::part_pkg->by_key($pkgpart);
      my $resale_mode = ($part_pkg->option('wholesale',1) ? 'R' : 'S');
      my $locationnum = $cust_pkg->locationnum;
      my $location = $cust_location{$locationnum} ||= $cust_pkg->cust_location;
      my %taxproduct; # CDR rated_classnum => taxproduct

      my $usage_total = 0;
      # go back to the original call details
      my $detailnums = FS::Record->scalar_sql(
        "SELECT array_to_string(array_agg(detailnum), ',') ".
        "FROM cust_bill_pkg_detail WHERE billpkgnum = ".
        $cust_bill_pkg->billpkgnum
      );

      # With summary details, even the number of CDRs returned from a single
      # invoice detail could be scary large.  Avoid running out of memory.
      if (length $detailnums > 0) {
        my $cdr_search = FS::Cursor->new({
          'table'     => 'cdr',
          'hashref'   => { freesidestatus => 'done' },
          'extra_sql' => "AND detailnum IN($detailnums)",
        });

        while (my $cdr = $cdr_search->fetch) {
          my $classnum = $cdr->rated_classnum;
          $classname{$classnum} ||= FS::usage_class->by_key($classnum)->classname
            if $classnum;
          $taxproduct{$classnum} ||= $part_pkg->taxproduct($classnum);
          if (!$taxproduct{$classnum}) {
            warn "part_pkg $pkgpart, class $classnum: ".
              ($taxproduct{$classnum} ?
                  "using taxproduct ".$taxproduct{$classnum}->description."\n" :
                  "taxproduct not found\n")
              if $DEBUG;
            next;
          }

          my $line = sprintf($format,
              substr($cdr->src, 0, 6), 'N',
              substr($cdr->dst, 0, 6), 'N',
              $location->geocode, 'P',
              $cust_type,
              $invoice_date,
              100000 * $cdr->rated_price, # price (5 decimal places)
              0,                          # lines
              0,                          # locations
              $taxproduct{$classnum}->taxproduct,
              $resale_mode,
              ($location->incorporated ? 'I' : 'O'),
              'C', # for Call
              $cdr->acctid,
              # Call duration (tenths of minutes)
              $cdr->duration / 6,
              # Service class indicator ('L'ocal, Long 'D'istance)
              # stupid hack
              (lc($classname{$classnum}) eq 'local' ? 'L' : 'D'),
            );

          print $fh $line;

          $usage_total += $cdr->rated_price;

        } # while $cdr = $cdr_search->fetch
      } # if @$detailnums; otherwise there are no usage details for this line
      
      my $recur_tcode;
      # now write lines for the non-CDR portion of the charges
      foreach (qw(setup recur)) {
        my $taxproduct = $part_pkg->taxproduct($_);
        warn "part_pkg $pkgpart, class $_: ".
          ($taxproduct ?
            "using taxproduct ".$taxproduct->description."\n" :
            "taxproduct not found\n")
          if $DEBUG;
        next unless $taxproduct;

        my ($tcode) = $taxproduct->taxproduct =~ /^(\d{6})/;
        $sales{$tcode} ||= {};
        $sales{$tcode}{$location->locationnum} ||= 0;
        $recur_tcode = $tcode if $_ eq 'recur';

        my $price = $cust_bill_pkg->get($_);
        $sales{$tcode}{$location->locationnum} += $price;

        $price -= $usage_total if $_ eq 'recur';

        my $line = sprintf($format,
          $location->geocode, 'P', # all 3 locations the same
          $location->geocode, 'P',
          $location->geocode, 'P',
          $cust_type,
          $invoice_date,
          100000 * $price,            # price (5 decimal places)
          0,                          # lines
          0,                          # locations
          $taxproduct->taxproduct,
          $resale_mode,
          ($location->incorporated ? 'I' : 'O'),
          substr(uc($_), 0, 1), # 'S'etup or 'R'ecur
          $cust_bill_pkg->billpkgnum,
          0, # call duration
          'D' # service class indicator
        );

        print $fh $line;

      } # foreach (setup, recur)

      # S-code 23: taxes based on number of lines (E911, mostly)
      # voip_cdr and voip_inbound packages know how to report this.  Not all 
      # T-codes are eligible for this; only report it if the /23 taxproduct
      # exists.
      #
      # (note: the nomenclature of "service" and "transaction" codes is 
      # backward from the way most people would use the terms.  you'd think
      # that in "cellular activation", "cellular" would be the service and 
      # "activation" would be the transaction, but for Billsoft it's the 
      # reverse.  I recommend calling them "S" and "T" codes internally just 
      # to avoid confusion.)

      my $lines_taxproduct = qsearchs('part_pkg_taxproduct', {
        'taxproduct' => sprintf('%06d%06d', $recur_tcode, 21)
      });
      my $lines = $cust_bill_pkg->units;

      if ( $lines_taxproduct and $lines ) {

        my $line = sprintf($format,
          $location->geocode, 'P', # all 3 locations the same
          $location->geocode, 'P',
          $location->geocode, 'P',
          $cust_type,
          $invoice_date,
          0,                        # price (5 decimal places)
          $lines,                   # lines
          0,                        # locations
          $lines_taxproduct->taxproduct,
          $resale_mode,
          ($location->incorporated ? 'I' : 'O'),
          'L',                      # 'L'ines
          $cust_bill_pkg->billpkgnum,
          0, # call duration
          'D' # service class indicator
        );

      }

    } # foreach my $cust_bill_pkg

    # Implicit transactions
    foreach my $tcode (keys %sales) {

      # S-code 23: number of locations (rare)
      my $locations_taxproduct =
        qsearchs('part_pkg_taxproduct', {
          'taxproduct' => sprintf('%06d%06d', $tcode, 23)
        });

      if ( $locations_taxproduct and keys %{ $sales{$tcode} } > 0 ) {
        my $location = $cust_main->bill_location;
        my $line = sprintf($format,
          $location->geocode, 'P', # all 3 locations the same
          $location->geocode, 'P',
          $location->geocode, 'P',
          $cust_type,
          $invoice_date,
          0,                        # price (5 decimal places)
          0,                        # lines
          keys(%{ $sales{$tcode} }),# locations
          $locations_taxproduct->taxproduct,
          'S',
          ($location->incorporated ? 'I' : 'O'),
          'O',                      # l'O'cations
          sprintf('%07d%06d%06d', $invnum, $tcode, 0),
          0, # call duration
          'D' # service class indicator
        );

        print $fh $line;
      }

      # S-code 43: per-invoice tax (apparently this is a thing)
      my $invoice_taxproduct = 
        qsearchs('part_pkg_taxproduct', {
          'taxproduct' => sprintf('%06d%06d', $tcode, 43)
        });
      if ( $invoice_taxproduct ) {
        my $location = $cust_main->bill_location;
        my $line = sprintf($format,
          $location->geocode, 'P', # all 3 locations the same
          $location->geocode, 'P',
          $location->geocode, 'P',
          $cust_type,
          $invoice_date,
          0,                        # price (5 decimal places)
          0,                        # lines
          0,                        # locations
          $invoice_taxproduct->taxproduct,
          'S',                      # resale mode
          ($location->incorporated ? 'I' : 'O'),
          'I',                      # 'I'nvoice tax
          sprintf('%07d%06d%06d', $invnum, $tcode, 0),
          0, # call duration
          'D' # service class indicator
        );

        print $fh $line;
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

  # create the batch
  my $upload = $self->create_batch(%opt);

  # upload it
  my $ftp = $target->connect;
  if (!ref $ftp) { # it's an error message
    die "Error connecting to Billsoft FTP server:\n$ftp\n";
  }
  my $fh = IO::File->new();
  warn "Processing: $upload\n";
  my $error = system("zip -j -o FTP.ZIP $upload");
  die "Failed to compress tax batch\n$!\n" if $error;
  warn "Uploading file...\n";
  $ftp->put('FTP.ZIP');

  my $download = $upload;
  # naming convention for these is: same as the CDF contained in the 
  # zip file, but with an "R" inserted after the company ID prefix
  $download =~ s/^(...)(\d{8}..).CDF/$1R$2.ZIP/;
  warn "Waiting for output file ($download)...\n";
  my $starttime = time;
  my $downloaded = 0;
  while ( time - $starttime < $TIMEOUT ) {
    my @ls = $ftp->ls($download);
    if ( @ls ) {
      if ($ftp->get($download, "download/$download")) {
        warn "Downloaded '$download'.\n";
        $downloaded = 1;
        last;
      } else {
        warn "Failed to download '$download': ".$ftp->message."\n";
        # We know the file exists, so continue trying to download it.
        # Maybe the problem will get fixed.
      }
    }
    sleep 30;
  }
  if (!$downloaded) {
    warn "No output file received.\n";
    next BATCH;
  }
  warn "Decompressing...\n";
  system("unzip -o download/$download");
  foreach my $csf (glob "*.CSF") {
    warn "Processing '$csf'...\n";
    $fh->open($csf, '<') or die "failed to open downloaded file $csf";
    $self->batch_import($fh); # dies on error
    $fh->close;
    unlink $csf unless $DEBUG;
  }
  unlink 'FTP.ZIP';
  move($upload, "upload/$upload");
  warn "Finished.\n";
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
  my $parser = Parse::FixedLength->new(
    [
      # key     => 20, # for our purposes we split it up
      flag      => 1,
      pkey      => 19,
      taxtype   => 6,
      authority => 1,
      sign      => 1,
      amount    => 11,
      pcode     => 9,
    ],
  );

  # start parsing the input file
  my $errors = 0;
  my $row = 1;
  foreach my $line (<$fh>) {
    warn $line if $DEBUG > 1;
    %$href = ();
    $href = $parser->parse($line);
    # convert some of these to integers
    $href->{$_} += 0 foreach(qw(pkey taxtype amount pcode));
    next if $href->{amount} == 0; # then nobody cares

    my $flag = $href->{flag};
    my $pkey = $href->{pkey};
    my $cust_bill_pkg; # the line item that this tax applies to
    # resolve the taxable object
    if ( $flag eq 'C' ) {
      # this line represents a CDR.
      my $cdr = FS::cdr->by_key($pkey);
      if (!$cdr) {
        warn "[$row]\tCDR #$pkey not found.\n";
      } elsif (!$cdr->detailnum) {
        warn "[$row]\tCDR #$pkey has not been billed.\n";
        $errors++;
        next;
      } else {
        my $detail = FS::cust_bill_pkg_detail->by_key($cdr->detailnum);
        $cust_bill_pkg = $detail->cust_bill_pkg;
      }
    } elsif ( $flag =~ /S|R|L/ ) {
      # this line represents a setup or recur fee, or a number of lines.
      $cust_bill_pkg = FS::cust_bill_pkg->by_key($pkey);
      if (!$cust_bill_pkg) {
        warn "[$row]\tLine item #$pkey not found.\n";
      }
    } elsif ( $flag =~ /O|I/ ) {
      warn "Per-invoice taxes are not implemented.\n";
    } else {
      warn "[$row]\tFlag '$flag' not recognized.\n";
    }
    if (!$cust_bill_pkg) {
      $errors++; # this will trigger a rollback of the transaction
      next;
    }
    # resolve the tax definition
    # base name of the tax type (like "Sales Tax" or "Universal Lifeline 
    # Telephone Service Charge").
    my $tax_class = $TAX_CLASSES{ $href->{taxtype} + 0 };
    if (!$tax_class) {
      warn "[$row]\tUnknown tax type $href->{taxtype}.\n";
      $errors++;
      next;
    }
    my $itemdesc = uc($tax_class->description);
    my $location = qsearchs('tax_rate_location',
                            { geocode => $href->{pcode} }
                           );
    if (!$location) {
      warn "Unknown tax authority location ".$href->{pcode}."\n";
      $errors++;
      next;
    }
    # jurisdiction name
    my $prefix = '';
    if ( $href->{authority} == 0 ) { # national-level tax
      # do nothing
    } elsif ( $href->{authority} == 1 ) {
      $prefix = $location->state;
    } elsif ( $href->{authority} == 2 ) {
      $prefix = $location->county . ' COUNTY';
    } elsif ( $href->{authority} == 3 ) {
      $prefix = $location->city;
    } elsif ( $href->{authority} == 4 ) { # unincorporated area ta
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
      geocode     => $href->{pcode},
      taxclassnum => $tax_class->taxclassnum,
      taxname     => $itemdesc,
    );
    # Convert amount from 10^-5 dollars to dollars/cents
    my $amount = sprintf('%.2f', $href->{amount} / 100000);
    # and add it to the tax under this name
    my $tax_item = $self->add_tax_item(
      invnum      => $cust_bill_pkg->invnum,
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
        taxable_billpkgnum  => $cust_bill_pkg->billpkgnum,
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
