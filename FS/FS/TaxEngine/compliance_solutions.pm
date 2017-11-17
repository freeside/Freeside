package FS::TaxEngine::compliance_solutions;

#some false laziness w/ suretax... uses/based on cch data?  or just imitating
# parts of their interface?

use strict;
use base qw( FS::TaxEngine );
use FS::Conf;
use FS::Record qw( dbh ); #qw( qsearch qsearchs dbh);
use Data::Dumper;
use Date::Format;
use Cpanel::JSON::XS;
use SOAP::Lite;

our $DEBUG = 1; # prints progress messages
   $DEBUG = 2; # prints decoded request and response (noisy, be careful)
#   $DEBUG = 3; # prints raw response from the API, ridiculously unreadable

our $json = Cpanel::JSON::XS->new->pretty(1);

our %taxproduct_cache;

our $conf;

FS::UID->install_callback( sub {
    $conf = FS::Conf->new;
    # should we enable conf caching here?
});

our %REGCODE = ( # can be selected per agent
#  ''          => '99',
  'ILEC'      => '00',
  'IXC'       => '01',
  'CLEC'      => '02',
  'VOIP'      => '03',
  'ISP'       => '04',
  'Wireless'  => '05',
);

sub info {
  { batch    => 0,
    override => 0, #?
  }
}

sub add_sale { } # nothing to do here

sub build_input {
  my( $self, $cust_bill ) = @_;

  my $cust_main = $cust_bill->cust_main;

  %taxproduct_cache = ();

  # assemble invoice line items 
  my @lines = map { $self->build_input_item($_, $cust_bill, $cust_main) }
                  $cust_bill->cust_bill_pkg;

  return if !@lines;

  return \@lines;

}

sub build_input_item {
  my( $self, $cust_bill_pkg, $cust_bill, $cust_main ) = @_;

  # get the part_pkg/fee for this line item, and the relevant part of the
  # taxproduct cache
  my $part_item = $cust_bill_pkg->part_X;
  my $taxproduct_of_class = do {
    my $part_id = $part_item->table . '#' . $part_item->get($part_item->primary_key);
    $taxproduct_cache{$part_id} ||= {};
  };

  my @items = ();

  my $recur_without_usage = $cust_bill_pkg->recur;

  ###
  # Usage charges
  ###

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
      push @items, {
        $self->generic_item($cust_bill, $cust_main),
        record_type   => 'C',
        unique_id     => 'cdr ' . $cdr->acctid.
                         ' cust_bill_pkg '.$cust_bill_pkg->billpkgnum, 
        productcode   => substr($taxproduct,0,4),
        servicecode   => substr($taxproduct,4,3),
        orig_Num      => $cdr->src,
        term_Num      => $cdr->dst,
        bill_Num      => $cdr->charged_party,
        charge_amount => $cdr->rated_price, # 4 decimal places
        minutes       => sprintf('%.1f', $cdr->billsec / 60 ),
      };

    } # while ($cdrs->fetch)

    # decrement the recurring charge
    $recur_without_usage -= $cust_bill_pkg_detail->amount;

  } # while ($details->fetch)

  ###
  # Recurring charge
  ###

  if ( $recur_without_usage > 0 ) {
    my $taxproduct = $taxproduct_of_class->{ 'recur' } ||= do {
      my $part_pkg_taxproduct = $part_item->taxproduct('recur');
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : '';
    };
    die "no taxproduct configured for pkgpart ".$part_item->pkgpart.
        " recurring charge\n"
        if !$taxproduct;

    my %item = (
      $self->generic_item($cust_bill, $cust_main),
      record_type     => 'S',
      unique_id       => 'cust_bill_pkg '. $cust_bill_pkg->billpkgnum. ' recur',
      charge_amount   => $recur_without_usage,
      productcode     => substr($taxproduct,0,4),
      servicecode     => substr($taxproduct,4,3),
    );

    # when billing on cancellation there are no units
    $item{units} = $self->{cancel} ? 0 : $cust_bill_pkg->units;

    my $location =  $cust_bill_pkg->tax_location
                 || ( $conf->exists('tax-ship_address')
                        ? $cust_main->ship_location
                        : $cust_main->bill_location
                    );
    $item{location_a} = $location->zip;

    unshift @items, \%item;
  }

  ###
  # Setup charge
  ###

  if ( $cust_bill_pkg->setup > 0 ) {
    my $taxproduct = $taxproduct_of_class->{ 'setup' } ||= do {
      my $part_pkg_taxproduct = $part_item->taxproduct('setup');
      $part_pkg_taxproduct ? $part_pkg_taxproduct->taxproduct : '';
    };
    die "no taxproduct configured for pkgpart ".$part_item->pkgpart.
        " setup charge\n"
        if !$taxproduct;

    my %item = (
      $self->generic_item($cust_bill, $cust_main),
      record_type     => 'S',
      unique_id       => 'cust_bill_pkg '. $cust_bill_pkg->billpkgnum. ' setup',
      charge_amount   => $cust_bill_pkg->setup,
      productcode     => substr($taxproduct,0,4),
      servicecode     => substr($taxproduct,4,3),
      units           => $cust_bill_pkg->units,
    );

    my $location =  $cust_bill_pkg->tax_location
                 || ( $conf->exists('tax-ship_address')
                        ? $cust_main->ship_location
                        : $cust_main->bill_location
                    );
    $item{location_a} = $location->zip;

    unshift @items, \%item;
  }

  return @items;

}

sub generic_item {
  my( $self, $cust_bill, $cust_main ) = @_;

  warn 'regcode '. $self->{regcode} if $DEBUG;

  (
    account_number            => $cust_bill->custnum,
    customer_type             => ( $cust_main->company =~ /\S/ ? '01' : '00' ),
    invoice_date              => time2str('%Y%m%d', $cust_bill->_date),
    invoice_number            => $cust_bill->invnum,
    provider                  => $self->{regcode},
    safe_harbor_override_flag => 'N',
    exempt_code               => $cust_main->tax,
  );

}

sub make_taxlines {
  my( $self, $cust_bill ) = @_;

  die "compliance_solutions-regulatory_code setting is not configured\n"
    unless $conf->config('compliance_solutions-regulatory_code', $cust_bill->cust_main->agentnum);

  $self->{regcode} = $REGCODE{ $conf->config('compliance_solutions-regulatory_code', $cust_bill->cust_main->agentnum) };

  warn 'regcode '. $self->{regcode} if $DEBUG;

  # assemble the request hash
  my $input = $self->build_input($cust_bill);
  if (!$input) {
    warn "no taxable items in invoice; skipping Compliance Solutions request\n" if $DEBUG;
    return;
  }

  warn "sending Compliance Solutions request\n" if $DEBUG;
  my $request_json = $json->encode(
    {
      'access_code' => $conf->config('compliance_solutions-access_code'),
      'reference'   => 'Invoice #'. $cust_bill->invnum,
      'input'       => $input,
    }
  );
  warn $request_json if $DEBUG > 1;
  $cust_bill->taxengine_request($request_json);

  my $soap = SOAP::Lite->service("http://tcms1.csilongwood.com/cgi-bin/taxcalc.wsdl");

  $soap->soapversion('1.2'); #service appears to be flaky with the default 1.1

  my $results = $soap->tax_rate($request_json);

  my %json_result = %{ $json->decode( $results ) };
  warn Dumper(%json_result) if $DEBUG > 1;

  # handle $results is empty / API/connection failure?

  # status OK
  unless ( $json_result{status} =~ /^\s*OK\s*$/i ) {
    warn Dumper($json_result{error_codes}) unless $DEBUG > 1;
    die 'Compliance Solutions returned status '. $json_result{status}.
           "; see log for error_codes detail\n";
  }

  # transmission_error No errors.
  unless ( $json_result{transmission_error} =~ /^\s*No\s+errors\.\s*$/i ) {
    warn Dumper($json_result{error_codes}) unless $DEBUG > 1;
    die 'Compliance Solutions returned transmission_error '. $json_result{transmission_error}.
           "; see log for error_codes detail\n";
  }


  # error_codes / No errors (for all records... check them individually in loop?

  my @elements = ();

  #handle the response
  foreach my $tax_data ( @{ $json_result{tax_data} } ) {

    # create a tax rate location if there isn't one yet
    my $taxname = $tax_data->{descript};
    my $tax_rate = FS::tax_rate->new({
        data_vendor   => 'compliance_solutions',
        taxname       => $taxname,
        taxclassnum   => '',
        taxauth       => $tax_data->{'taxauthtype'}, # federal / state / city / district
        geocode       => $tax_data->{'geocode'},
        tax           => 0, #not necessary because we query for rates on the
        fee           => 0, # fly and only store this for the name -> code map??
    });
    my $error = $tax_rate->find_or_insert;
    die "error inserting tax_rate record for '$taxname': $error\n"
      if $error;
    $tax_rate = $tax_rate->replace_old;

    my $tax_rate_location = FS::tax_rate_location->new({
        data_vendor => 'compliance_solutions',
        geocode     => $tax_data->{'geocode'},
        district    => $tax_data->{'geo_district'},
        state       => $tax_data->{'geo_state'},
        county      => $tax_data->{'geo_county'},
        country     => 'US',
    });
    $error = $tax_rate_location->find_or_insert;
    die 'error inserting tax_rate_location record for '.  $tax_data->{state}.
        '/'. $tax_data->{country}. ' ('. $tax_data->{'geocode'}. "): $error\n"
      if $error;
    $tax_rate_location = $tax_rate_location->replace_old;

    #unique id: a cust_bill_pkg (setup/recur) or cdr record

    my $taxable_billpkgnum = '';
    if ( $tax_data->{'unique_id'} =~ /^cust_bill_pkg (\d+)/ ) {
      $taxable_billpkgnum = $1;
    } elsif ( $tax_data->{'unique_id'} =~ /^cdr (\d+) cust_bill_pkg (\d+)$/ ) {
      $taxable_billpkgnum = $2;
    } else {
      die 'unparseable unique_id '. $tax_data->{'unique_id'};
    }

    push @elements, FS::cust_bill_pkg_tax_rate_location->new({
      taxable_billpkgnum  => $taxable_billpkgnum,
      taxnum              => $tax_rate->taxnum,
      taxtype             => 'FS::tax_rate',
      taxratelocationnum  => $tax_rate_location->taxratelocationnum,
      amount              => sprintf('%.2f', $tax_data->{taxamount}),
    });

  }

  return @elements;
}

sub add_taxproduct {
  my $class = shift;
  my $desc = shift; # tax code and description, separated by a space.
  if ($desc =~ s/^(\w{7}+) //) {
    my $part_pkg_taxproduct = FS::part_pkg_taxproduct->new({
        'data_vendor' => 'compliance_solutions',
        'taxproduct'  => $1,
        'description' => $desc,
    });
    # $obj_or_error
    return $part_pkg_taxproduct->insert || $part_pkg_taxproduct;
  } else {
    return "illegal compliance solutions tax code '$desc'";
  }
}

1;
