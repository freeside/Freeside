package FS::TaxEngine::suretax;

use strict;
use base 'FS::TaxEngine';
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbh);
use JSON;
use XML::Simple qw(XMLin);
use LWP::UserAgent;
use HTTP::Request::Common;
use DateTime;

our $DEBUG = 1; # prints progress messages
#   $DEBUG = 2; # prints decoded request and response (noisy, be careful)
#   $DEBUG = 3; # prints raw response from the API, ridiculously unreadable

our $json = JSON->new->pretty(1);

our %taxproduct_cache;

our $conf;

FS::UID->install_callback( sub {
    $conf = FS::Conf->new;
    # should we enable conf caching here?
});

# Tax Situs Rules, for determining tax jurisdiction.
# (may need to be configurable)

# For PSTN calls, use Rule 01, two-out-of-three using NPA-NXX. (The "three" 
# are source number, destination number, and charged party number.)
our $TSR_CALL_NPANXX = '01';

# For other types of calls (on-network hosted PBX, SIP-addressed calls, 
# other things that don't have an NPA-NXX number), use Rule 11. (See below.)
our $TSR_CALL_OTHER = '11';

# For regular recurring or one-time charges, use Rule 11. This uses the 
# service zip code for transaction types that are known to require it, and
# the billing zip code for all other transaction types.
our $TSR_GENERAL = '11';

# XXX incomplete; doesn't handle international taxes (Rule 14) or point
# to point private lines (Rule 07).

our %REGCODE = ( # can be selected per agent
  ''          => '99',
  'ILEC'      => '00',
  'IXC'       => '01',
  'CLEC'      => '02',
  'VOIP'      => '03',
  'ISP'       => '04',
  'Wireless'  => '05',
);

sub info {
  { batch => 0,
    override => 0,
  }
}

sub add_sale { } # nothing to do here

sub build_request {
  my ($self, %opt) = @_;

  my $cust_bill = $self->{cust_bill};
  my $cust_main = $cust_bill->cust_main;
  my $agentnum = $cust_main->agentnum;
  my $date = DateTime->from_epoch(epoch => $cust_bill->_date);

  # remember some things that are linked to the customer
  $self->{taxstatus} = $cust_main->taxstatus
    or die "Customer #".$cust_main->custnum." has no tax status defined.\n";

  ($self->{bill_zip}, $self->{bill_plus4}) =
    split('-', $cust_main->bill_location->zip);

  $self->{regcode} = $REGCODE{ $conf->config('suretax-regulatory_code') };

  %taxproduct_cache = ();

  # assemble invoice line items 
  my @lines = map { $self->build_item($_) }
              $cust_bill->cust_bill_pkg;

  my $ClientNumber = $conf->config('suretax-client_number')
    or die "suretax-client_number config required.\n";
  my $ValidationKey = $conf->config('suretax-validation_key')
    or die "suretax-validation_key config required.\n";
  my $BusinessUnit = $conf->config('suretax-business_unit', $agentnum) || '';

  return {
    ClientNumber  => $ClientNumber,
    ValidationKey => $ValidationKey,
    BusinessUnit  => $BusinessUnit,
    DataYear      => '2015', #$date->year,
    DataMonth     => '04', #sprintf('%02d', $date->month),
    TotalRevenue  => sprintf('%.4f', $cust_bill->charged),
    ReturnFileCode    => ($self->{estimate} ? 'Q' : '0'),
    ClientTracking  => $cust_bill->invnum,
    IndustryExemption => '',
    ResponseGroup => '13',
    ResponseType  => 'D2',
    STAN          => '',
    ItemList      => \@lines,
  };
}

=item build_item CUST_BILL_PKG

Takes a sale item and returns any number of request element hashrefs
corresponding to it. Yes, any number, because in a rated usage line item
we have to send each usage detail separately.

=cut

sub build_item {
  my $self = shift;
  my $cust_bill_pkg = shift;
  my $cust_bill = $cust_bill_pkg->cust_bill;
  my $billpkgnum = $cust_bill_pkg->billpkgnum;
  my $invnum = $cust_bill->invnum;
  my $custnum = $cust_bill->custnum;

  # get the part_pkg/fee for this line item, and the relevant part of the
  # taxproduct cache
  my $part_item = $cust_bill_pkg->part_X;
  my $taxproduct_of_class = do {
    my $part_id = $part_item->table . '#' . $part_item->get($part_item->primary_key);
    $taxproduct_cache{$part_id} ||= {};
  };

  my @items;
  my $recur_without_usage = $cust_bill_pkg->recur;

  my $location = $cust_bill_pkg->tax_location;
  my ($svc_zip, $svc_plus4) = split('-', $location->zip);

  my $startdate =
    DateTime->from_epoch( epoch => $cust_bill->_date )->strftime('%m-%d-%Y');

  my %base_item = (
    'LineNumber'      => '',
    'InvoiceNumber'   => $billpkgnum,
    'CustomerNumber'  => $custnum,
    'OrigNumber'      => '',
    'TermNumber'      => '',
    'BillToNumber'    => '',
    'Zipcode'         => $self->{bill_zip},
    'Plus4'           => ($self->{bill_plus4} ||= '0000'),
    'P2PZipcode'      => $svc_zip,
    'P2PPlus4'        => ($svc_plus4 ||= '0000'),
    # we don't support Order Placement/Approval zip codes
    'Geocode'         => '',
    'TransDate'       => $startdate,
    'Revenue'         => '',
    'Units'           => 0,
    'UnitType'        => '00', # "number of unique lines", the only choice
    'Seconds'         => 0,
    'TaxIncludedCode' => '0',
    'TaxSitusRule'    => '',
    'TransTypeCode'   => '',
    'SalesTypeCode'   => $self->{taxstatus},
    'RegulatoryCode'  => $self->{regcode},
    'TaxExemptionCodeList' => [ ],
    'AuxRevenue'      => 0, # we don't currently support freight and such
    'AuxRevenueType'  => '',
  );

  # some naming conventions:
  # 'C#####' is a call detail record (using the acctid)
  # 'S#####' is a cust_bill_pkg setup element (using the billpkgnum)
  # 'R#####' is a cust_bill_pkg recur element
  # always set "InvoiceNumber" = the billpkgnum, so we can link it properly

  # cursor all this stuff; data sets can be LARGE
  # (if it gets really out of hand, we can also incrementally write JSON
  # to a file)

  my $details = FS::Cursor->new('cust_bill_pkg_detail', {
      billpkgnum  => $cust_bill_pkg->billpkgnum,
      amount      => { op => '>', value => 0 }
  }, dbh() );
  while ( my $cust_bill_pkg_detail = $details->fetch ) {

    # look up the tax product for this class
    my $classnum = $cust_bill_pkg_detail->classnum;
    my $taxproduct = $taxproduct_of_class->{ $classnum } ||= do {
      my $part_pkg_taxproduct = $part_item->taxproduct($classnum);
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : '';
    };
    die "no taxproduct configured for pkgpart ".$part_item->pkgpart.
        ", usage class $classnum\n"
        if !$taxproduct;

    my $cdrs = FS::Cursor->new('cdr', {
        detailnum       => $cust_bill_pkg_detail->detailnum,
        freesidestatus  => 'done',
    }, dbh() );
    while ( my $cdr = $cdrs->fetch ) {
      my $calldate =
        DateTime->from_epoch( epoch => $cdr->startdate )->strftime('%m-%d-%Y');
      # determine the tax situs rule; it's different (probably more accurate) 
      # if the call has PSTN phone numbers at both ends
      my $tsr = $TSR_CALL_OTHER;
      if ( $cdr->charged_party =~ /^\d{10}$/ and
           $cdr->src           =~ /^\d{10}$/ and
           $cdr->dst           =~ /^\d{10}$/ ) {
        $tsr = $TSR_CALL_NPANXX;
      }
      my %hash = (
        %base_item,
        'LineNumber'      => 'C' . $cdr->acctid,
        'OrigNumber'      => $cdr->src,
        'TermNumber'      => $cdr->dst,
        'BillToNumber'    => $cdr->charged_party,
        'TransDate'       => $calldate,
        'Revenue'         => $cdr->rated_price, # 4 decimal places
        'Units'           => 0, # right?
        'CallDuration'    => $cdr->duration,
        'TaxSitusRule'    => $tsr,
        'TransTypeCode'   => $taxproduct,
      );
      push @items, \%hash;

    } # while ($cdrs->fetch)

    # decrement the recurring charge
    $recur_without_usage -= $cust_bill_pkg_detail->amount;

  } # while ($details->fetch)

  # recurring charge
  if ( $recur_without_usage > 0 ) {
    my $taxproduct = $taxproduct_of_class->{ 'recur' } ||= do {
      my $part_pkg_taxproduct = $part_item->taxproduct('recur');
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : '';
    };
    die "no taxproduct configured for pkgpart ".$part_item->pkgpart.
        " recurring charge\n"
        if !$taxproduct;

    my $tsr = $TSR_GENERAL;
    my %hash = (
      %base_item,
      'LineNumber'      => 'R' . $billpkgnum,
      'Revenue'         => $recur_without_usage, # 4 decimal places
      'Units'           => $cust_bill_pkg->units,
      'TaxSitusRule'    => $tsr,
      'TransTypeCode'   => $taxproduct,
    );
    # API expects all these fields to be _present_, even when they're not 
    # required
    $hash{$_} = '' foreach(qw(OrigNumber TermNumber BillToNumber));
    push @items, \%hash;
  }

  if ( $cust_bill_pkg->setup > 0 ) {
    my $startdate =
      DateTime->from_epoch( epoch => $cust_bill->_date )->strftime('%m-%d-%Y');
    my $taxproduct = $taxproduct_of_class->{ 'setup' } ||= do {
      my $part_pkg_taxproduct = $part_item->taxproduct('setup');
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : '';
    };
    die "no taxproduct configured for pkgpart ".$part_item->pkgpart.
        " setup charge\n"
        if !$taxproduct;

    my $tsr = $TSR_GENERAL;
    my %hash = (
      %base_item,
      'LineNumber'      => 'S' . $billpkgnum,
      'Revenue'         => $cust_bill_pkg->setup, # 4 decimal places
      'Units'           => $cust_bill_pkg->units,
      'TaxSitusRule'    => $tsr,
      'TransTypeCode'   => $taxproduct,
    );
    push @items, \%hash;
  }

  @items;
}

sub make_taxlines {
  my $self = shift;

  my @elements;

  my $cust_bill = shift;
  if (!$cust_bill->invnum) {
    die "FS::TaxEngine::suretax can't calculate taxes on a non-inserted invoice\n";
  }
  $self->{cust_bill} = $cust_bill;
  my $cust_main = $cust_bill->cust_main;
  my $country = $cust_main->bill_location->country;

  my $invnum = $cust_bill->invnum;
  if (FS::cust_bill_pkg->count("invnum = $invnum") == 0) {
    # don't even bother making the request
    # (why are we even here, then? invoices with no line items
    # should not be created)
    return;
  }

  # assemble the request hash
  my $request = $self->build_request;

  warn "sending SureTax request\n" if $DEBUG;
  my $request_json = $json->encode($request);
  warn $request_json if $DEBUG > 1;

  my $host = $conf->config('suretax-hostname');
  $host ||= 'testapi.taxrating.net';

  # We are targeting the "V05" interface:
  # - accepts both telecom and general sales transactions
  # - produces results broken down by "invoice" (Freeside line item)
  my $ua = LWP::UserAgent->new;
  my $http_response =  $ua->request(
   POST "https://$host/Services/V05/SureTax.asmx/PostRequest",
    [ request => $request_json ],
    'Content-Type'  => 'application/x-www-form-urlencoded',
    'Accept'        => 'application/json',
  );

  my $raw_response = $http_response->content;
  warn "received response\n" if $DEBUG;
  warn $raw_response if $DEBUG > 2;
  my $response;
  if ( $raw_response =~ /^<\?xml/ ) {
    # an error message wrapped in a riddle inside an enigma inside an XML
    # document...
    $response = XMLin( $raw_response );
    $raw_response = $response->{content};
  }
  $response = eval { $json->decode($raw_response) }
    or die "$raw_response\n";

  # documentation implies this might be necessary
  $response = $response->{'d'} if exists $response->{'d'};

  warn $json->encode($response) if $DEBUG > 1;
 
  if ( $response->{Successful} ne 'Y' ) {
    die $response->{HeaderMessage}."\n";
  } else {
    my $error = join("\n",
      map { $_->{"LineNumber"}.': '. $_->{Message} }
      @{ $response->{ItemMessages} }
    );
    die "$error\n" if $error;
  }

  return if !$response->{GroupList};
  foreach my $taxable ( @{ $response->{GroupList} } ) {
    # each member of this array here corresponds to what SureTax calls an
    # "invoice" and we call a "line item". The invoice number is 
    # cust_bill_pkg.billpkgnum.

    my ($state, $geocode) = split(/\|/, $taxable->{StateCode});
    foreach my $tax_element ( @{ $taxable->{TaxList} } ) {
      # create a tax rate location if there isn't one yet
      my $taxname = $tax_element->{TaxTypeDesc};
      my $taxauth = substr($tax_element->{TaxTypeCode}, 0, 1);
      my $tax_rate = FS::tax_rate->new({
          data_vendor   => 'suretax',
          taxname       => $taxname,
          taxclassnum   => '',
          taxauth       => $taxauth, # federal / state / city / district
          geocode       => $geocode, # this is going to disambiguate all
                                     # the taxes named "STATE SALES TAX", etc.
          tax           => 0,
          fee           => 0,
      });
      my $error = $tax_rate->find_or_insert;
      die "error inserting tax_rate record for '$taxname': $error\n"
        if $error;
      $tax_rate = $tax_rate->replace_old;

      my $tax_rate_location = FS::tax_rate_location->new({
          data_vendor => 'suretax',
          geocode     => $geocode,
          state       => $state,
          country     => $country,
      });
      $error = $tax_rate_location->find_or_insert;
      die "error inserting tax_rate_location record for '$geocode': $error\n"
        if $error;
      $tax_rate_location = $tax_rate_location->replace_old;

      push @elements, FS::cust_bill_pkg_tax_rate_location->new({
          taxable_billpkgnum  => $taxable->{InvoiceNumber},
          taxnum              => $tax_rate->taxnum,
          taxtype             => 'FS::tax_rate',
          taxratelocationnum  => $tax_rate_location->taxratelocationnum,
          amount              => sprintf('%.2f', $tax_element->{TaxAmount}),
      });
    }
  }
  return @elements;
}

sub add_taxproduct {
  my $class = shift;
  my $desc = shift; # tax code and description, separated by a space.
  if ($desc =~ s/^(\d{6}+) //) {
    my $part_pkg_taxproduct = FS::part_pkg_taxproduct->new({
        'data_vendor' => 'suretax',
        'taxproduct'  => $1,
        'description' => $desc,
    });
    # $obj_or_error
    return $part_pkg_taxproduct->insert || $part_pkg_taxproduct;
  } else {
    return "illegal suretax tax code '$desc'";
  }
}

1;
