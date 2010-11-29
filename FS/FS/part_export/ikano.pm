package FS::part_export::ikano;

use vars qw(@ISA %info %orderType %orderStatus %loopType $DEBUG $me);
use Tie::IxHash;
use Date::Format qw( time2str );
use Date::Parse qw( str2time );
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
# we distinguish between invalid new data (return error) versus data that
# has legitimately changed (may eventually execute hooks; now just update)

    my($self, $svc_dsl) = (shift, shift);
    my $result = $self->valid_order($svc_dsl,'pull');
    return $result unless $result eq '';
  
    $result = $self->ikano_command('ORDERSTATUS', 
	{ OrderId => $svc_dsl->vendor_order_id } ); 
    return $result unless ref($result); # scalar (string) is an error

    # now we're getting an OrderResponse which should have one Order in it
    warn "$me pull OrderResponse hash:\n".Dumper($result) if $DEBUG;
  
    return 'Invalid order response' unless defined $result->{'Order'};
    $result = $result->{'Order'};

    return 'No order id or status returned' 
	unless defined $result->{'Status'} && defined $result->{'OrderId'};

    # update this always (except in the above cases), even if error later
    $svc_dsl->last_pull((time));
    local $FS::svc_Common::noexport_hack = 1;
    local $FS::UID::AutoCommit = 1;
    my $error = $svc_dsl->replace; 
    return 'Error updating last pull time' if $error;

    # let's compare what we have to what we got back...
 
    # current assumptions of what won't change (from their side):
    # vendor_order_id, vendor_qual_id, vendor_order_type, pushed, monitored,
    # last_pull, address (from qual), contact info, ProductCustomId

    my $wechanged = 0;

    # 1. status 
    my $new_order_status = $self->orderstatus_long2short($result->{'Status'});
    return 'Invalid new status' if $new_order_status eq '';
    if($svc_dsl->vendor_order_status ne $new_order_status) {
	if($new_order_status eq 'X' || $new_order_status eq 'C') {
	    $svc_dsl->monitored('');
	}
	$svc_dsl->vendor_order_status($new_order_status);
	$wechanged = 1;
    }

    # 2. fields we don't care much about
    my %justUpdate = ( 'first' => 'FirstName',
		    'last' => 'LastName',
		    'company' => 'CompanyName',
		    'username' => 'Username',
		    'password' => 'Password' );

    while (($fsf, $ikanof) = each %justUpdate) {
       if ( $result->{$ikanof} ne $svc_dsl->$fsf ) {
	    $svc_dsl->$fsf($result->{$ikanof});
	    $wechanged = 1;
	}
    }

    # let's look inside the <Product> response element
    my @product = $result->{'Product'}; 
    return 'Invalid number of products on order' if scalar(@product) != 1;
    my $product = $result->{'Product'}[0];

    # 3. phonenum 
    if($svc_dsl->loop_type eq '') { # line-share
	# TN may change only if sub changes it and 
	# New or Change order in Completed status
	my $tn = $product->{'PhoneNumber'};
	if($tn ne $svc_dsl->phonenum) {
	    if( ($svc_dsl->vendor_order_type eq 'N' 
		|| $svc_dsl->vendor_order_type eq 'C')
	       && $svc_dsl->vendor_order_status eq 'C' ) {
		$svc_dsl->phonenum($tn);
		$wechanged = 1;
	    }
	    else { return 'TN has changed in an invalid state'; }
	}
    }
    elsif($svc_dsl->loop_type eq '0') { # dry loop
	return 'Invalid PhoneNumber value for a dry loop' 
	    if $product->{'PhoneNumber'} ne 'STANDALONE';
	my $tn = $product->{'VirtualPhoneNumber'};
	if($tn ne $svc_dsl->phonenum) {
	    if( ($svc_dsl->vendor_order_type eq 'N' 
		|| $svc_dsl->vendor_order_type eq 'C')
	      && $svc_dsl->vendor_order_status ne 'C'
	      && $svc_dsl->vendor_order_status ne 'X') {
		$svc_dsl->phonenum($tn);
		$wechanged = 1;
	    }
	}
    }
    
    # 4. desired_due_date - may change if manually changed
    if($svc_dsl->vendor_order_type eq 'N' 
	    || $svc_dsl->vendor_order_type eq 'C'){
	my $f = str2time($product->{'DateToOrder'});
	return 'Invalid DateToOrder' unless $f;
	if ( $svc_dsl->desired_due_date != $f ) {
	    $svc_dsl->desired_due_date($f);
	    $wechanged = 1;
	}
	# XXX: optionally sync back to start_date or whatever... 
    }
    elsif($svc_dsl->vendor_order_type eq 'X'){
	my $f = str2time($product->{'DateToDisconnect'});
	return 'Invalid DateToDisconnect' unless $f;
	if ( $svc_dsl->desired_due_date != $f ) {
	    $svc_dsl->desired_due_date($f);
	    $wechanged = 1;
	}
	# XXX: optionally sync back to expire or whatever... 
    }

    # 4. due_date
    if($svc_dsl->vendor_order_type eq 'N' 
 	  || $svc_dsl->vendor_order_type eq 'C') {
	my $f = str2time($product->{'ActivationDate'});
	if($svc_dsl->vendor_order_status ne 'N') {
	    return 'Invalid ActivationDate' unless $f;
	    if( $svc_dsl->due_date != $f ) {
		$svc_dsl->due_date($f);
		$wechanged = 1;
	    }
	}
    }
    # Ikano API does not implement the proper disconnect date,
    # so we can't do anything about it

    # 6. staticips - for now just comma-separate them
    my @statics = $result->{'StaticIps'};
# XXX

    # 7. notes - put them into the common format:
    # "by" = 0 for Ikano; 1 for ISP
    # "priority" = 1 for high priority; 0 otherwise
    my @notes = $result->{'OrderNotes'}; 
# XXX

    if($wechanged) { # you can't check ->modified, the replace above screws it
	# noexport_hack and AutoCommit are set correctly above
	$result = $svc_dsl->replace; 
	return 'Error updating DSL data' if $result;
    }

    '';
}

sub qual {
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
	$error = !($action eq 'pull'
	    && 	length($svc_dsl->vendor_order_id) > 0
	    && 	length($svc_dsl->vendor_order_status) > 0
		);
	return 'Invalid order data' if $error;
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
    my %rorderStatus = reverse %orderStatus;
    return $rorderStatus{$order_status} if exists $rorderStatus{$order_status};
    '';
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
