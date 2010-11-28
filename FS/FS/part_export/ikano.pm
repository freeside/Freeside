package FS::part_export::ikano;

use vars qw(@ISA %info %orderType %orderStatus %loopType $DEBUG $me);
use Tie::IxHash;
use Date::Format qw( time2str );
use FS::Record qw(qsearch qsearchs);
use FS::part_export;
use FS::svc_dsl;
use Data::Dumper;

@ISA = qw(FS::part_export);
$DEBUG = 1;
$me= '[' .  __PACKAGE__ . ']';

tie my %options, 'Tie::IxHash',
  'keyid'         => { label=>'Ikano keyid' },
  'username'      => { label=>'Ikano username',
			default => 'admin',
			},
  'password'      => { label=>'Ikano password' },
  'check_networks' => { label => 'Check Networks',
		    default => 'ATT,BELLCA',
		    },
;

%info = (
  'svc'     => 'svc_dsl',
  'desc'    => 'Provision DSL to Ikano',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-Ikano">Net::Ikano</a> from CPAN.
END
);
    
%orderType = ( 'N' => 'NEW', 'X' => 'CANCEL', 'C' => 'CHANGE' );
%orderStatus = ('N' => 'NEW',
		'P' => 'PENDING',
		'X' => 'CANCELLED',
		'C' => 'COMPLETED',
		'E' => 'ERROR' );
%loopType = ( '' => 'Line-share', '0' => 'Standalone' );

sub rebless { shift; }

sub dsl_pull {
    '';
}

sub dsl_qual {
    '';
}

sub notes_html {
    '';
}

sub loop_type_long { # sub, not a method
    my($svc_dsl) = (shift);
    return $loopType{$svc_dsl->loop_type};
}

sub status_line {
    my($self,$svc_dsl) = (shift,shift);
    return "Ikano ".$orderType{$svc_dsl->vendor_order_type}." order #"
	. $svc_dsl->vendor_order_id . " (Status: " 
	. $orderStatus{$svc_dsl->vendor_order_status} . ")";
}

sub ikano_command {
  my( $self, $command, $args ) = @_;

  eval "use Net::Ikano;";
  die $@ if $@;

  my $ikano = Net::Ikano->new(
    'keyid' => $self->option('keyid'),
    'username'  => $self->option('username'),
    'password'  => $self->option('password'),
    'debug'    => 1,
    #'reqpreviewonly' => 1,
  );

  $ikano->$command($args);
}

sub valid_order {
  my( $self, $svc_dsl, $action ) = (shift, shift, shift);
  
  warn "$me valid_order action=$action svc_dsl:\n". Dumper($svc_dsl) if $DEBUG;

  # common to all order types/status/loop_type
  my $error = !($svc_dsl->desired_due_date
	    &&  defined $orderType{$svc_dsl->vendor_order_type}
	    &&  $svc_dsl->first
	    &&	$svc_dsl->last
	    &&	defined $svc_dsl->loop_type
	    &&  $svc_dsl->vendor_qual_id
	    );
  return 'Missing or invalid order data' if $error;
  
  return 'Package does not have an external id configured'
    if $svc_dsl->cust_svc->cust_pkg->part_pkg->options('externalid',1) eq '';

  return 'No valid qualification for this order' 
    unless qsearch( 'qual', { 'vendor_qual_id' => $svc_dsl->vendor_qual_id });

  # now go by order type
  # weird ifs & long lines for readability and ease of understanding - don't change
  if($svc_dsl->vendor_order_type eq 'N') {
    if($svc_dsl->pushed) {
    }
    else { # unpushed New order - cannot do anything other than push it
	$error = !($action eq 'insert'
	    && 	length($svc_dsl->vendor_order_id) < 1
	    && 	length($svc_dsl->vendor_order_status) < 1
	    && ( ($svc_dsl->phonenum eq '' && $svc_dsl->loop_type eq '0') # dry
	      || ($svc_dsl->phonenum ne '' && $svc_dsl->loop_type eq '') # line-share
	       )
	    );	
	return 'Invalid order data' if $error;
    }
  }
  elsif($svc_dsl->vendor_order_type eq 'X') {
  }
  elsif($svc_dsl->vendor_order_type eq 'C') {
  }

 '';
}

sub qual2termsid {
    my ($self,$vendor_qual_id,$ProductCustomId) = (shift,shift,shift);
    my $qual = qsearchs( 'qual', { 'vendor_qual_id' => $vendor_qual_id });
    return '' unless $qual;
    my %qual_options = $qual->options;
    while (($optionname, $optionvalue) = each %qual_options) {
	if ( $optionname =~ /^ikano_Network_(\d+)_ProductGroup_(\d+)_Product_(\d+)_ProductCustomId$/ 
	    && $optionvalue eq $ProductCustomId ) {
	    my $network = $1;
	    my $productgroup = $2;
	    return $qual->option("ikano_Network_".$network."_ProductGroup_".$productgroup."_TermsId");
	}
    }
    '';
}

sub orderstatus_long2short {
    my ($self,$order_status) = (shift,shift);
    while (($k, $v) = each %orderStatus) {
	return $k if $v eq $order_status;
    }
    return '';
}

sub _export_insert {
  my( $self, $svc_dsl ) = (shift, shift);

  my $result = $self->valid_order($svc_dsl,'insert');
  return $result unless $result eq '';

  my $isp_chg = $svc_dsl->isp_chg eq 'Y' ? 'YES' : 'NO';
  my $contactTN = $svc_dsl->cust_svc->cust_pkg->cust_main->daytime;
  $contactTN =~ s/[^0-9]//g;

  my $ProductCustomId = $svc_dsl->cust_svc->cust_pkg->part_pkg->option('externalid',1);

  my $args = {
	orderType => 'NEW',
	ProductCustomId => $ProductCustomId,
	TermsId => $self->qual2termsid($svc_dsl->vendor_qual_id,$ProductCustomId),
	DSLPhoneNumber => $svc_dsl->loop_type eq '0' ? 'STANDALONE'
						    : $svc_dsl->phonenum,
	Password => $svc_dsl->password,
	PrequalId => $svc_dsl->vendor_qual_id,
	CompanyName => $svc_dsl->company,
	FirstName => $svc_dsl->first,
	LastName => $svc_dsl->last,
	MiddleName => '',
	ContactMethod => 'PHONE',
	ContactPhoneNumber => $contactTN,
	ContactEmail => 'x@x.xx',
	ContactFax => '',
	DateToOrder => time2str("%Y-%m-%d",$svc_dsl->desired_due_date),
	RequestClientIP => '127.0.0.1',
	IspChange => $isp_chg,
	IspPrevious => $isp_chg eq 'YES' ? $svc_dsl->isp_prev : '',
	CurrentProvider => $isp_chg eq 'NO' ? $svc_dsl->isp_prev : '',
  };

  $result = $self->ikano_command('ORDER',$args); 
  return $result unless ref($result); # scalar (string) is an error

  # now we're getting an OrderResponse which should have one Order in it
  warn "$me _export_insert OrderResponse hash:\n".Dumper($result) if $DEBUG;
  
  return 'Invalid order response' unless defined $result->{'Order'};
  $result = $result->{'Order'};

  return 'No order id or status returned' 
    unless defined $result->{'Status'} && defined $result->{'OrderId'};

  $svc_dsl->pushed(time);
  $svc_dsl->last_pull((time)+1); 
  $svc_dsl->vendor_order_id($result->{'OrderId'});
  $svc_dsl->vendor_order_status($self->orderstatus_long2short($result->{'Status'}));
  $svc_dsl->username($result->{'Username'});
  local $FS::svc_Common::noexport_hack = 1;
  local $FS::UID::AutoCommit = 0;
  $result = $svc_dsl->replace; 
  return 'Error setting DSL fields' if $result;
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  '';
}

sub _export_delete {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

sub _export_suspend {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

sub _export_unsuspend {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

1;
