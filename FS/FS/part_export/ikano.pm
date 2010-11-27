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
    
%orderType = ( 'N' => 'New', 'X' => 'Cancel', 'C' => 'Change' );
%orderStatus = ('N' => 'New',
		'P' => 'Pending',
		'X' => 'Cancelled',
		'C' => 'Completed',
		'E' => 'Error' );
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
  
  warn "$me valid_order action=$action svc_dsl: ". Dumper($svc_dsl) if $DEBUG;

  # common to all order types/status/loop_type
  my $error = !($svc_dsl->desired_dd 
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
	    && ( ($svc_dsl->svctn eq '' && $svc_dsl->loop_type eq '0') # dry
	      || ($svc_dsl->svctn ne '' && $svc_dsl->loop_type eq '') # line-share
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
    my ($self,$vendor_qual_id) = (shift,shift);
    my $qual = qsearchs( 'qual', { 'vendor_qual_id' => $vendor_qual_id });
    return '' unless $qual;
    my %qual_options = $qual->options;
    foreach my $optionname ( keys %qual_options ) {
	if ( $optionname =~ /^ikano_network_(\d+)_productgroup_(\d+)_termsid$/ ) {
	    return $qual_options{$optionname};
	}
	# XXX finish this properly - the above is wrong
    }
    '';
}

sub _export_insert {
  my( $self, $svc_dsl ) = (shift, shift);

  my $result = $self->valid_order($svc_dsl,'insert');
  return $result unless $result eq '';

  my $isp_chg = $svc_dsl->isp_chg eq 'Y' ? 'YES' : 'NO';
  my $contactTN = $svc_dsl->cust_svc->cust_pkg->cust_main->daytime;
  $contactTN =~ s/[^0-9]//g;

  my $args = {
	orderType => 'NEW',
	ProductCustomId => 
	    $svc_dsl->cust_svc->cust_pkg->part_pkg->option('externalid',1),
	TermsId => $self->qual2termsid($svc_dsl->vendor_qual_id),
	DSLPhoneNumber => $svc_dsl->loop_type eq '0' ? 'STANDALONE'
						    : $svc_dsl->svctn,
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
	DateToOrder => time2str("%Y-%m-%d",$svc_dsl->desired_dd),
	RequestClientIP => '127.0.0.1',
	IspChange => $isp_chg,
	IspPrevious => $isp_chg eq 'YES' ? $svc_dsl->isp_prev : '',
	CurrentProvider => $isp_chg eq 'NO' ? $svc_dsl->isp_prev : '',
  };

  $result = $self->ikano_command('ORDER',$args); 
  return $result unless ref($result); # scalar (string) is an error

  # now we're getting an OrderResponse which should have one Order in it
  warn Dumper($result) if $DEBUG;
  my ($pushed,$vendor_order_id,$vendor_order_status,$last_pull);
  $pushed = time;
  $last_pull = time;
  $last_pull++;
  
  return 'Invalid order response' unless defined $result->{'Order'};
  $result = $result->{'Order'};

  return 'No order id or status returned' 
    unless defined $result->{'Status'} && defined $result->{'OrderId'};

  $vendor_order_id = $result->{'OrderId'};
  $vendor_order_status = $result->{'Status'};
      
# XXX we need to set all of these values (everything in the last my statement
# above) in the svc without:
# a. re-triggering exports
# b. committing the svc into the db now (because other things in the caller
#  and further up the stack may decide that the svc shouldn't be inserted)

  return '';
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
