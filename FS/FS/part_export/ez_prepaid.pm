package FS::part_export::ez_prepaid;

use base qw( FS::part_export );

use strict;
use vars qw(@ISA %info $version $replace_ok_kludge $product_info);
use Tie::IxHash;
use FS::Record qw( qsearchs );
use FS::svc_external;
use SOAP::Lite;
use XML::Simple qw( xml_in );
use Data::Dumper;

$version = '01';

my $product_info;
my %language_id = ( English => 1, Spanish => 2 );

tie my %options, 'Tie::IxHash',
  'site_id'     => { label => 'Site ID' },
  'clerk_id'    => { label => 'Clerk ID' },
#  'product_id'  => { label => 'Product ID' }, use the 'title' field
#  'amount'      => { label => 'Purchase amount' },
  'language'    => { label => 'Language',
                     type  => 'select',
                     options => [ 'English', 'Spanish' ],
                    },

  'debug'       => { label => 'Debug level',
                     type  => 'select', options => [0, 1, 2 ] },
;

%info = (
  'svc'     => 'svc_external',
  'desc'    => 'Purchase EZ-Prepaid PIN',
  'options' => \%options,
  'notes'   => <<'END'
<P>Export to the EZ-Prepaid PIN purchase service.  If the purchase is allowed,
the PIN will be stored as svc_external.id.</P>
<P>svc_external.title must contain the product ID, and should be set as a fixed
field in the service definition.  For a list of product IDs, see the 
"Merchant Info" tab in the EZ Prepaid reseller portal.</P>
END
  );

$replace_ok_kludge = 0;

sub _export_insert {
  my ($self, $svc_external) = @_;

  # the name on the certificate is 'debisys.com', for some reason
  local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

  my $pin = eval { $self->ez_prepaid_PinDistSale( $svc_external->title ) };
  return $@ if $@;

  local($replace_ok_kludge) = 1;
  $svc_external->set('id', $pin);
  $svc_external->replace;
}

sub _export_replace {
  $replace_ok_kludge ? '' : "can't change PIN after purchase";
}

sub _export_delete {
  "can't delete PIN after purchase";
}

# possibly options at some point to relate these to agentnum/usernum
sub site_id { $_[0]->option('site_id') }

sub clerk_id { $_[0]->option('clerk_id') }

sub ez_prepaid_PinDistSale {
  my $self = shift;
  my $product_id = shift;
  $self->ez_prepaid_init; # populate product ID cache
  my $info = $product_info->{$product_id};
  if ( $info ) {
    if ( $self->option('debug') ) {
      warn "Purchasing PIN product #$product_id:\n" .
            $info->{Description}."\n".
            $info->{CurrencyCode} . ' ' .$info->{Amount}."\n";
    }
  } else { #no $info
    die "Unknown PIN product #$product_id.\n";
  }

  my $response = $self->ez_prepaid_request(
    'PinDistSale',
    $version,
    $self->site_id,
    $self->clerk_id,
    $product_id,
    '', # AccountID, not used for PIN sale
    $product_info->{$product_id}->{Amount},
    $self->svcnum,
    ($language_id{ $self->option('language') } || 1),
  );
  if ( $self->option('debug') ) {
    warn Dumper($response);
    # includes serial number and transaction ID, possibly useful
    # (but we don't have a structured place to store it--maybe in 
    # a customer note?)
  }
  $response->{Pin};
}

sub ez_prepaid_init {
  # returns the SOAP client object
  my $self = shift;
  my $wsdl = 'https://webservice.ez-prepaid.com/soap/webServices.wsdl';

  if ( $self->option('debug') >= 2 ) {
    SOAP::Lite->import(+trace => [transport => \&log_transport ]);
  }
 
  if ( !$self->client ) {
    $self->set(client => SOAP::Lite->new->service($wsdl));
    # I don't know if this can happen, but better to bail out here
    # than go into recursion.
    die "Error creating SOAP client\n" if !$self->client;
  }

  if ( !defined($product_info) ) {
    # for now we only support the 'PIN' type
    my $response = $self->ez_prepaid_request(
      'GetTransTypeList', $version, $self->site_id, '', '', '', ''
    );
    my %transtype = map { $_->{Description} => $_->{TransTypeId} }
      @{ $response->{TransType} };

    if ( !exists $transtype{PIN} ) {
      warn "'PIN' transaction type not available.\n";
      # or else your site ID is wrong
      return;
    }

    $response = $self->ez_prepaid_request(
      'GetProductList',
      $version,
      $self->option('site_id'),
      $transtype{PIN},
      '', #CarrierId
      '', #CategoryId
      '', #ProductId
    );
    $product_info = +{
      map { $_->{ProductId} => $_ }
      @{ $response->{Product} }
    };
  } #!defined $product_info
}

sub log_transport {
  my $in = shift;
  if ( UNIVERSAL::can($in, 'content') ) {
    warn $in->content."\n";
  }
}

my @ForceArray = qw(TransType Product); # add others as needed
sub ez_prepaid_request {
  my $self = shift;
  # takes a method name and param list,
  # returns a hashref containing the unpacked response
  # or dies on error
  
  $self->ez_prepaid_init if !$self->client;

  my $method = shift;
  my $xml = $self->client->$method(@_);
  # All of their response data types are one part, a string, containing 
  # an encoded XML structure, containing the fields described in the docs.
  my $response = xml_in($xml, ForceArray => \@ForceArray);
  if ( exists($response->{ResponseCode}) && $response->{ResponseCode} > 0 ) {
    die "[$method] ".$response->{ResponseMessage};
  }
  $response;
}

1;
