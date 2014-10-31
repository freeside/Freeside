package FS::TaxEngine::avalara;

use strict;
use base 'FS::TaxEngine';
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbh);
use FS::cust_pkg;
use FS::cust_location;
use FS::cust_bill_pkg;
use FS::tax_rate;
use JSON;
use Geo::StreetAddress::US;

our $DEBUG = 2;
our $json = JSON->new->pretty(1);

our $conf;

sub info {
  { batch => 0,
    override => 0 }
}

FS::UID->install_callback( sub {
    $conf = FS::Conf->new;
});

#sub cust_tax_locations {
#}
# Avalara address standardization would be nice but isn't necessary

# XXX this is just here to avoid reworking the framework right now. By the
# 4.0 release, ALL tax calculations should be done after the invoice has 
# been inserted into the database.

# nothing to do here
sub add_sale {}

sub build_request {
  my ($self, %opt) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill = $self->{cust_bill};
  my $cust_main = $cust_bill->cust_main;

  # unfortunately we can't directly use the Business::Tax::Avalara get_tax()
  # interface, because we have multiple customer addresses
  my %address_seen;
 
  # assemble invoice line items 
  my @lines;
  # conventions we are using here:
  # P#### = part pkg#
  # F#### = part_fee#
  # L#### = cust_location# (address code)
  # L0 = company address
  foreach my $sale ( $cust_bill->cust_bill_pkg ) {
    my $part = $sale->part_X;
    my $item_code = ($part->isa('FS::part_pkg') ? 'P'.$part->pkgpart :
                                                  'F'.$part->feepart
                    );
    my $addr_code = 'L'.$sale->tax_locationnum;
    my $taxproductnum = $part->taxproductnum;
    next unless $taxproductnum;
    my $taxproduct = FS::part_pkg_taxproduct->by_key($taxproductnum);
    my $itemdesc = $part->itemdesc || $part->pkg;

    $address_seen{$sale->tax_locationnum} = 1;

    my $line = {
      'LineNo'            => $sale->billpkgnum,
      'DestinationCode'   => $addr_code,
      'OriginCode'        => 'L0',
      'ItemCode'          => $item_code,
      'TaxCode'           => $taxproduct->taxproduct,
      'Description'       => $itemdesc,
      'Qty'               => $sale->quantity,
      'Amount'            => ($sale->setup + $sale->recur),
      # also available:
      # 'ExemptionNo', 'Discounted', 'TaxIncluded', 'Ref1', 'Ref2', 'Ref3',
      # 'TaxOverride'
    };
    push @lines, $line;
  }

  # assemble address records for any cust_locations we used here, plus
  # the company address
  # XXX these should just be separate config opts
  my $our_address = join(' ', 
    $conf->config('company_address', $cust_main->agentnum)
  );
  my $company_address = Geo::StreetAddress::US->parse_address($our_address);
  my $address1 = join(' ', grep $_, @{$company_address}{qw(
      number prefix street type suffix
  )});
  my $address2 = join(' ', grep $_, @{$company_address}{qw(
      sec_unit_type sec_unit_num
  )});
  my @addrs = (
    {
      'AddressCode'       => 'L0',
      'Line1'             => $address1,
      'Line2'             => $address2,
      'City'              => $company_address->{city},
      'Region'            => $company_address->{state},
      'Country'           => ($company_address->{country}
                              || $conf->config('countrydefault')
                              || 'US'),
      'PostalCode'        => $company_address->{zip},
      'Latitude'          => ($conf->config('company_latitude') || ''),
      'Longitude'         => ($conf->config('company_longitude') || ''),
    }
  );

  foreach my $locationnum (keys %address_seen) {
    my $cust_location = FS::cust_location->by_key($locationnum);
    my $addr = {
      'AddressCode'       => 'L'.$locationnum,
      'Line1'             => $cust_location->address1,
      'Line2'             => $cust_location->address2,
      'Line3'             => '',
      'City'              => $cust_location->city,
      'Region'            => $cust_location->state,
      'Country'           => $cust_location->country,
      'PostalCode'        => $cust_location->zip,
      'Latitude'          => $cust_location->latitude,
      'Longitude'         => $cust_location->longitude,
      #'TaxRegionId', probably not necessary
    };
    push @addrs, $addr;
  }

  my @avalara_conf = $conf->config('avalara-taxconfig');
  # 1. company code
  # 2. user name (account number)
  # 3. password (license)
  # 4. test mode (1 to enable)

  # create the top level object
  my $date = DateTime->from_epoch(epoch => $self->{invoice_time});
  return {
    'CustomerCode'      => $cust_main->custnum,
    'DocDate'           => $date->strftime('%Y-%m-%d'),
    'CompanyCode'       => $avalara_conf[0],
    'Client'            => "Freeside $FS::VERSION",
    'DocCode'           => $cust_bill->invnum,
    'DetailLevel'       => 'Tax',
    'Commit'            => 'false',
    'DocType'           => 'SalesInvoice', # ???
    'CustomerUsageType' => $cust_main->taxstatus,
    # ExemptionNo, Discount, TaxOverride, PurchaseOrderNo,
    'Addresses'         => \@addrs,
    'Lines'             => \@lines,
  };
}

sub calculate_taxes {
  $DB::single = 1; # XXX
  my $self = shift;

  my $cust_bill = shift;
  if (!$cust_bill->invnum) {
    warn "FS::TaxEngine::avalara: can't calculate taxes on a non-inserted invoice";
    return;
  }
  $self->{cust_bill} = $cust_bill;

  my $invnum = $cust_bill->invnum;
  if (FS::cust_bill_pkg->count("invnum = $invnum") == 0) {
    # don't even bother making the request
    return [];
  }

  # instantiate gateway
  eval "use Business::Tax::Avalara";
  die "error loading Business::Tax::Avalara:\n$@\n" if $@;

  my @avalara_conf = $conf->config('avalara-taxconfig');
  if (scalar @avalara_conf < 3) {
    die "Your Avalara configuration is incomplete.
The 'avalara-taxconfig' parameter must have three rows: company code, 
account number, and license key.
";
  }

  my $gateway = Business::Tax::Avalara->new(
    customer_code   => $self->{cust_main}->custnum,
    company_code    => $avalara_conf[0],
    user_name       => $avalara_conf[1],
    password        => $avalara_conf[2],
    is_development  => ($avalara_conf[3] ? 1 : 0),
  );

  # assemble the request hash
  my $request = $self->build_request;

  warn "sending Avalara tax request\n" if $DEBUG;
  my $request_json = $json->encode($request);
  warn $request_json if $DEBUG > 1;

  my $response_json = $gateway->_make_request_json($request_json);
  warn "received response\n" if $DEBUG;
  warn $response_json if $DEBUG > 1;
  my $response = $json->decode($response_json);
 
  my %tax_item_named;

  if ( $response->{ResultCode} ne 'Success' ) {
    return "invoice#".$cust_bill->invnum.": ".
           join("\n", @{ $response->{Messages} });
  }
  warn "creating taxes for inv#$invnum\n" if $DEBUG > 1;
  foreach my $TaxLine (@{ $response->{TaxLines} }) {
    my $taxable_billpkgnum = $TaxLine->{LineNo};
    warn "  item #$taxable_billpkgnum\n" if $DEBUG > 1;
    foreach my $TaxDetail (@{ $TaxLine->{TaxDetails} }) {
      # in this case the tax doesn't apply (just informational)
      next unless $TaxDetail->{Taxable};

      my $taxname = $TaxDetail->{TaxName};
      warn "    $taxname\n" if $DEBUG > 1;

      # create a tax line item
      my $tax_item = $tax_item_named{$taxname} ||= FS::cust_bill_pkg->new({
          invnum    => $cust_bill->invnum,
          pkgnum    => 0,
          setup     => 0,
          recur     => 0,
          itemdesc  => $taxname,
          cust_bill_pkg_tax_rate_location => [],
      });
      # create a tax_rate record if there isn't one yet.
      # we're not actually going to do anything with it, just tie related
      # taxes together.
      my $tax_rate = FS::tax_rate->new({
          data_vendor => 'avalara',
          taxname     => $taxname,
          taxclassnum => '',
          geocode     => $TaxDetail->{JurisCode},
          location    => $TaxDetail->{JurisName},
          tax         => 0,
          fee         => 0,
      });
      my $error = $tax_rate->find_or_insert;
      return "error inserting tax_rate record for '$taxname': $error\n"
        if $error;

      # create a tax_rate_location record
      my $tax_rate_location = FS::tax_rate_location->new({
          data_vendor => 'avalara',
          geocode     => $TaxDetail->{JurisCode},
          state       => $TaxDetail->{Region},
          city        => ($TaxDetail->{JurisType} eq 'City' ?
                          $TaxDetail->{JurisName} : ''),
          county      => ($TaxDetail->{JurisType} eq 'County' ?
                          $TaxDetail->{JurisName} : ''),
                        # country?
      });
      $error = $tax_rate_location->find_or_insert;
      return "error inserting tax_rate_location record for ".
              $TaxDetail->{JurisCode} .": $error\n"
        if $error;

      # create a link record
      my $tax_link = FS::cust_bill_pkg_tax_rate_location->new({
          cust_bill_pkg       => $tax_item,
          taxtype             => 'FS::tax_rate',
          taxnum              => $tax_rate->taxnum,
          taxratelocationnum  => $tax_rate_location->taxratelocationnum,
          amount              => $TaxDetail->{Tax},
          taxable_billpkgnum  => $taxable_billpkgnum,
      });

      # append the tax link and increment the amount
      push @{ $tax_item->get('cust_bill_pkg_tax_rate_location') }, $tax_link;
      $tax_item->set('setup', $tax_item->get('setup') + $TaxDetail->{Tax});
    } # foreach $TaxDetail
  } # foreach $TaxLine

  return [ values(%tax_item_named) ];
}

sub add_taxproduct {
  my $class = shift;
  my $desc = shift; # tax code and description, separated by a space.
  if ($desc =~ s/^(\w+) //) {
    my $part_pkg_taxproduct = FS::part_pkg_taxproduct->new({
        'data_vendor' => 'avalara',
        'taxproduct'  => $1,
        'description' => $desc,
    });
    # $obj_or_error
    return $part_pkg_taxproduct->insert || $part_pkg_taxproduct;
  } else {
    return "illegal avalara tax code '$desc'";
  }
}

1;
