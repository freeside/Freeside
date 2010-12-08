package FS::part_export::ikano;

use strict;
use warnings;
use vars qw(@ISA %info %loopType $me);
use Tie::IxHash;
use Date::Format qw( time2str );
use Date::Parse qw( str2time );
use FS::Record qw(qsearch qsearchs dbh);
use FS::part_export;
use FS::svc_dsl;
use Data::Dumper;

@ISA = qw(FS::part_export);
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
  'debug' => { label => 'Debug Mode',  type => 'checkbox' },
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
    
%loopType = ( '' => 'Line-share', '0' => 'Standalone' );

sub rebless { shift; }

sub external_pkg_map { 1; }

sub dsl_pull {
# we distinguish between invalid new data (return error) versus data that
# has legitimately changed (may eventually execute hooks; now just update)
# if we do add hooks later, we should work on a copy of svc_dsl and pass
# the old and new svc_dsl to the hooks so they know what changed
#
# current assumptions of what won't change (from their side):
# vendor_order_id, vendor_qual_id, vendor_order_type, pushed, monitored,
# last_pull, address (from qual), contact info, ProductCustomId
    my($self, $svc_dsl, $threshold) = (shift, shift, shift);
    $self->loadmod;
    my $result = $self->valid_order($svc_dsl,'pull');
    return $result unless $result eq '';

    my $now = time;
    if($now - $svc_dsl->last_pull < $threshold) {
	warn "$me skipping pull since threshold not reached (svcnum="
	    . $svc_dsl->svcnum . ",now=$now,threshold=$threshold,last_pull="
	    . $svc_dsl->last_pull .")" if $self->option('debug');
	return '';
    }
  
    $result = $self->ikano_command('ORDERSTATUS', 
	{ OrderId => $svc_dsl->vendor_order_id } ); 
    return $result unless ref($result); # scalar (string) is an error

    # now we're getting an OrderResponse which should have one Order in it
    warn "$me pull OrderResponse hash:\n".Dumper($result) 
	if $self->option('debug');
  
    return 'Invalid order response' unless defined $result->{'Order'};
    $result = $result->{'Order'};

    return 'No order id or status returned' 
	unless defined $result->{'Status'} && defined $result->{'OrderId'};
	
    local $SIG{HUP} = 'IGNORE';
    local $SIG{INT} = 'IGNORE';
    local $SIG{QUIT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';
    local $SIG{TSTP} = 'IGNORE';
    local $SIG{PIPE} = 'IGNORE';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    # 1. status 
    my $order_status = grep($_ eq $result->{'Status'}, @Net::Ikano::orderStatus)
			    ? $result->{'Status'} : '';
    return 'Invalid new status' if $order_status eq '';
    $svc_dsl->vendor_order_status($order_status) 
	if($svc_dsl->vendor_order_status ne $order_status);
    $svc_dsl->monitored('') 
	    if ($order_status eq 'CANCELLED' || $order_status eq 'COMPLETED');

    # 2. fields we don't care much about
    my %justUpdate = ( 'first' => 'FirstName',
		    'last' => 'LastName',
		    'company' => 'CompanyName',
		    'username' => 'Username',
		    'password' => 'Password' );

    my($fsf, $ikanof);
    while (($fsf, $ikanof) = each %justUpdate) {
       $svc_dsl->$fsf($result->{$ikanof}) 
	    if $result->{$ikanof} ne $svc_dsl->$fsf;
    }

    # let's look inside the <Product> response element
    my @product = $result->{'Product'}; 
    return 'Invalid number of products on order' if scalar(@product) != 1;
    my $product = $result->{'Product'}[0];

    # 3. phonenum 
    if($svc_dsl->loop_type eq '') { # line-share
# TN may change only if sub changes it and New or Change order in Completed status
	my $tn = $product->{'PhoneNumber'};
	if($tn ne $svc_dsl->phonenum) {
	    if( ($svc_dsl->vendor_order_type eq 'NEW' 
		|| $svc_dsl->vendor_order_type eq 'CHANGE')
	       && $svc_dsl->vendor_order_status eq 'COMPLETED' ) {
		$svc_dsl->phonenum($tn);
	    }
	    else { return 'TN has changed in an invalid state'; }
	}
    }
    elsif($svc_dsl->loop_type eq '0') { # dry loop
# TN may change only if it's assigned while a New or Change order is in progress
	return 'Invalid PhoneNumber value for a dry loop' 
	    if $product->{'PhoneNumber'} ne 'STANDALONE';
	my $tn = $product->{'VirtualPhoneNumber'};
	if($tn ne $svc_dsl->phonenum) {
	    if( ($svc_dsl->vendor_order_type eq 'NEW' 
		|| $svc_dsl->vendor_order_type eq 'CHANGE')
	      && $svc_dsl->vendor_order_status ne 'COMPLETED'
	      && $svc_dsl->vendor_order_status ne 'CANCELLED') {
		$svc_dsl->phonenum($tn);
	    }
	    else { return 'TN has changed in an invalid state'; }
	}
    }
    
    # 4. desired_due_date - may change if manually changed
    if($svc_dsl->vendor_order_type eq 'NEW' 
	    || $svc_dsl->vendor_order_type eq 'CHANGE'){
	my $f = str2time($product->{'DateToOrder'});
	return 'Invalid DateToOrder' unless $f;
	$svc_dsl->desired_due_date($f) if $svc_dsl->desired_due_date ne $f;
	# XXX: optionally sync back to start_date or whatever... 
    }
    elsif($svc_dsl->vendor_order_type eq 'CANCEL'){
	my $f = str2time($product->{'DateToDisconnect'});
	return 'Invalid DateToDisconnect' unless $f;
	$svc_dsl->desired_due_date($f) if $svc_dsl->desired_due_date ne $f;
	# XXX: optionally sync back to expire or whatever... 
    }

    # 5. due_date
    if($svc_dsl->vendor_order_type eq 'NEW' 
 	  || $svc_dsl->vendor_order_type eq 'CHANGE') {
	my $f = str2time($product->{'ActivationDate'});
	if($svc_dsl->vendor_order_status ne 'NEW'
	    && $svc_dsl->vendor_order_status ne 'CANCELLED') {
	    return 'Invalid ActivationDate' unless $f;
	    $svc_dsl->due_date($f) if $svc_dsl->due_date ne $f;
	}
    }
    # Ikano API does not implement the proper disconnect date,
    # so we can't do anything about it

    # 6. staticips - for now just comma-separate them
    my $tstatics = $result->{'StaticIps'};
    my @istatics = defined $tstatics ? @$tstatics : ();
    my $ostatics = $svc_dsl->staticips;
    my @ostatics = split(',',$ostatics);
    # more horrible search/sync code below...
    my $staticsChanged = 0;
    foreach my $istatic ( @istatics ) { # they have, we don't
	unless ( grep($_ eq $istatic, @ostatics) ) {
	    push @ostatics, $istatic;
	    $staticsChanged = 1;
	}
    }
    for(my $i=0; $i < scalar(@ostatics); $i++) {
	unless ( grep($_ eq $ostatics[$i], @istatics) ) {
	    splice(@ostatics,$i,1);
	    $i--;
	    $staticsChanged = 1;
	}
    }
    $svc_dsl->staticips(join(',',@ostatics)) if $staticsChanged;

    # 7. notes - put them into the common format and compare
    my $tnotes = $result->{'OrderNotes'}; 
    my @tnotes = defined $tnotes ? @$tnotes : ();
    my @inotes = (); # all Ikano OrderNotes as FS::dsl_note objects
    my $notesChanged = 0; 
    foreach my $tnote ( @tnotes ) {
	my $inote = $self->ikano2fsnote($tnote,$svc_dsl->svcnum);
	return 'Cannot parse note' unless ref($inote);
	push @inotes, $inote;
    }
    my @onotes = $svc_dsl->notes;
    # assume notes we already have don't change & no notes added from our side
    # so using the horrible code below just find what we're missing and add it
    my $error;
    foreach my $inote ( @inotes ) {
	my $found = 0;
	foreach my $onote ( @onotes ) {
	    if($onote->date == $inote->date && $onote->note eq $inote->note) {
		$found = 1;
		last;
	    }
	}
	$error = $inote->insert unless ( $found );
	if ( $error ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "Cannot add note: $error";
	}
    }
    
    $svc_dsl->last_pull((time));
    local $FS::svc_Common::noexport_hack = 1;
    $error = $svc_dsl->replace; 
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Cannot update DSL data: $error";
    }

    $dbh->commit or die $dbh->errstr if $oldAutoCommit;

    '';
}

sub ikano2fsnote {
    my($self,$n,$svcnum) = (shift,shift,shift);
    my @ikanoRequired = qw( HighPriority StaffId Date Text CompanyStaffId );
    return '' unless defined $n->{'HighPriority'}
		&& defined $n->{'StaffId'}
		&& defined $n->{'CompanyStaffId'}
		&& defined $n->{'Date'}
		&& defined $n->{'Text'}
		;
    my $by = 'Unknown';
    $by = "Ikano" if $n->{'CompanyStaffId'} == -1 && $n->{'StaffId'} != -1;
    $by = "Us" if $n->{'StaffId'} == -1 && $n->{'CompanyStaffId'} != -1;

    new FS::dsl_note( {
	'svcnum' => $svcnum,
	'author' => $by,
	'priority' => $n->{'HighPriority'} eq 'false' ? 'N' : 'H',
	'_date' => int(str2time($n->{'Date'})),
	'note' => $n->{'Text'},
     } );
}

sub qual {
    my($self,$qual) = (shift,shift);
# address always required for Ikano qual, TN optional (assume dry if not given)

    my %location_hash = $qual->location; 
    return 'No address provided' unless %location_hash;
    my $svctn = $qual->phonenum;

    my $result = $self->ikano_command('PREQUAL',
      { AddressLine1 => $location_hash{address1},
	AddressUnitType => $location_hash{location_type},
	AddressUnitValue => $location_hash{location_number},
	AddressCity => $location_hash{city},
	AddressState => $location_hash{state},
	ZipCode => $location_hash{zip},
	Country => $location_hash{country},
	LocationType => $location_hash{location_kind},
	PhoneNumber => length($svctn) > 1 ? $svctn : "STANDALONE",
	RequestClientIP => '127.0.0.1',
	CheckNetworks => $self->option('check_networks'),
      } ); 
    return $result unless ref($result); # error case
    return 'Invalid prequal response' unless defined $result->{'PrequalId'};

    my $qoptions = {};
    # lame data structure traversal...
    # don't spend much time here, just get TermsId and ProductCustomId
    my $networks = $result->{'Network'};
    my @networks = defined $networks ? @$networks : ();
    my $netcount = 0;
    foreach my $network ( @networks ) { 
	my $productgroups = $network->{'ProductGroup'};
	my @productgroups = defined $productgroups ? @$productgroups : ();
	my $pgcount = 0;
	foreach my $productgroup ( @productgroups ) {
	    my $prefix = "ikano_Network_$netcount"."_ProductGroup_$pgcount"."_";
	    $qoptions->{$prefix."TermsId"} = $productgroup->{'TermsId'};
	    my $products = $productgroup->{'Product'};
	    my @products = defined $products ? @$products : ();
	    my $prodcount = 0;
	    foreach my $product ( @products ) {
		$qoptions->{$prefix."Product_$prodcount"."_ProductCustomId"} = $product->{'ProductCustomId'};
		$prodcount++;
	    }
	    $pgcount++;
	}
	$netcount++;
    }

    {	'vendor_qual_id' => $result->{'PrequalId'},
	'status' => scalar(@networks) ? 'Q' : 'D',
	'options' => $qoptions,
    };
}

sub qual_html {
    my($self,$qual) = (shift,shift);
    
    my %qual_options = $qual->options;
    my @externalids = ();
    my( $optionname, $optionvalue );
    while (($optionname, $optionvalue) = each %qual_options) {
	push @externalids, $optionvalue 
	    if ( $optionname =~ /^ikano_Network_(\d+)_ProductGroup_(\d+)_Product_(\d+)_ProductCustomId$/
		&& $optionvalue ne '' );
    }

    # XXX: eventually perhaps this should return both the packages a link to
    # order each package and go to the svc prov with the prequal id filled in
    # but only if cust, not prospect!
    my $list = "<B>Qualifying Packages:</B><UL>";
    my @part_pkgs = qsearch( 'part_pkg', { 'disabled' => '' } );
    foreach my $part_pkg ( @part_pkgs ) {
	my $externalid = $part_pkg->option('externalid',1);
	if ( $externalid ) {
	    $list .= "<LI>".$part_pkg->pkgpart.": ".$part_pkg->pkg." - "
		.$part_pkg->comment."</LI>" 
	      if grep( $_ eq $externalid, @externalids );
	}
    }
    $list .= "</UL>";
    $list;
}

sub notes_html { 
    my($self,$svc_dsl) = (shift,shift);
    my $conf = new FS::Conf;
    my $date_format = $conf->config('date_format') || '%m/%d/%Y';
    my @notes = $svc_dsl->notes;
    my $html = '<TABLE border="1" cellspacing="2" cellpadding="2" id="dsl_notes">
	<TR><TH>Date</TH><TH>By</TH><TH>Priority</TH><TH>Note</TH></TR>';
    foreach my $note ( @notes ) {
	$html .= "<TR>
	    <TD>".time2str("$date_format %H:%M",$note->date)."</TD>
	    <TD>".$note->by."</TD>
	    <TD>". ($note->priority eq 'N' ? 'Normal' : 'High') ."</TD>
	    <TD>".$note->note."</TD></TR>";
    }
    $html .= '</TABLE>';
    $html;
}

sub loop_type_long { # sub, not a method
    my($svc_dsl) = (shift);
    return $loopType{$svc_dsl->loop_type};
}

sub ikano_command {
  my( $self, $command, $args ) = @_;

  $self->loadmod;

  my $ikano = Net::Ikano->new(
    'keyid' => $self->option('keyid'),
    'username'  => $self->option('username'),
    'password'  => $self->option('password'),
    'debug'    => $self->option('debug'),
  );

  $ikano->$command($args);
}

sub loadmod {
  eval "use Net::Ikano;";
  die $@ if $@;
}

sub valid_order {
  my( $self, $svc_dsl, $action ) = (shift, shift, shift);
 
  $self->loadmod;
  
  warn "$me valid_order action=$action svc_dsl:\n". Dumper($svc_dsl)
	if $self->option('debug');

  # common to all order types/status/loop_type
  my $error = !($svc_dsl->desired_due_date
	    &&  grep($_ eq $svc_dsl->vendor_order_type, Net::Ikano->orderTypes)
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
  if($svc_dsl->vendor_order_type eq 'NEW') {
    if($svc_dsl->pushed) {
	$error = !( ($action eq 'pull' || $action eq 'statuschg' 
			|| $action eq 'delete')
	    && 	length($svc_dsl->vendor_order_id) > 0
	    && 	length($svc_dsl->vendor_order_status) > 0
		);
	return 'Invalid order data' if $error;

	return 'Phone number required for status change'
	    if ($action eq 'statuschg' && length($svc_dsl->phonenum) < 1);
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
  elsif($svc_dsl->vendor_order_type eq 'CANCEL') {
  }
  elsif($svc_dsl->vendor_order_type eq 'CHANGE') {
  }

 '';
}

sub qual2termsid {
    my ($self,$vendor_qual_id,$ProductCustomId) = (shift,shift,shift);
    my $qual = qsearchs( 'qual', { 'vendor_qual_id' => $vendor_qual_id });
    return '' unless $qual;
    my %qual_options = $qual->options;
    my( $optionname, $optionvalue );
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

sub _export_insert {
  my( $self, $svc_dsl ) = (shift, shift);

  $self->loadmod;

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
  warn "$me _export_insert OrderResponse hash:\n".Dumper($result)
	if $self->option('debug');
  
  return 'Invalid order response' unless defined $result->{'Order'};
  $result = $result->{'Order'};

  return 'No/invalid order id or status returned' 
    unless defined $result->{'Status'} && defined $result->{'OrderId'}
	&& grep($_ eq $result->{'Status'}, @Net::Ikano::orderStatus);

  $svc_dsl->pushed(time);
  $svc_dsl->last_pull((time)+1); 
  $svc_dsl->vendor_order_id($result->{'OrderId'});
  $svc_dsl->vendor_order_status($result->{'Status'});
  $svc_dsl->username($result->{'Username'});
  local $FS::svc_Common::noexport_hack = 1;
  $result = $svc_dsl->replace; 
  return "Error setting DSL fields: $result" if $result;
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
# XXX only supports password changes now, but should return error if 
# another change is attempted?

  if($new->password ne $old->password) {
      my $result = $self->valid_order($new,'statuschg');
      return $result unless $result eq '';
      
      $result = $self->ikano_command('PASSWORDCHANGE',
	    { DSLPhoneNumber => $new->phonenum,
	      NewPassword => $new->password,
	    } ); 
      return $result unless ref($result); # scalar (string) is an error

      return 'Error changing password' unless defined $result->{'Password'}
	&& $result->{'Password'} eq $new->password;
  }

  '';
}

sub _export_delete {
  my( $self, $svc_dsl ) = (shift, shift);
  
  my $result = $self->valid_order($svc_dsl,'delete');
  return $result unless $result eq '';

  # for now allow an immediate cancel only on New orders in New/Pending status
  #XXX: add support for Chance and Cancel orders in New/Pending status later

  if($svc_dsl->vendor_order_type eq 'NEW') {
    if($svc_dsl->vendor_order_status eq 'NEW' 
	    || $svc_dsl->vendor_order_status eq 'PENDING') {
	my $result = $self->ikano_command('CANCEL', 
	    { OrderId => $svc_dsl->vendor_order_id, } );
	return $result unless ref($result); # scalar (string) is an error
	return 'Unable to cancel order' unless $result->{'Order'};
	$result = $result->{'Order'};
	return 'Invalid cancellation response' 
	    unless $result->{'Status'} eq 'CANCELLED' 
		&& $result->{'OrderId'} eq $svc_dsl->vendor_order_id;

	# we're supposed to do a pull, but it will break everything, so don't
	# this is very wrong...
    }
    else {
	return "Cannot cancel a NEW order unless it's in NEW or PENDING status";
    }
  }
  else {
    return 'Canceling orders other than NEW orders is not currently implemented';
  }

  '';
}

sub statuschg {
  my( $self, $svc_dsl, $type ) = (shift, shift, shift);

  my $result = $self->valid_order($svc_dsl,'statuschg');
  return $result unless $result eq '';

  # get the DSLServiceId
  $result = $self->ikano_command('CUSTOMERLOOKUP',
	{ PhoneNumber => $svc_dsl->phonenum } ); 
  return $result unless ref($result); # scalar (string) is an error
  return 'No DSLServiceId found' unless defined $result->{'DSLServiceId'};
  my $DSLServiceId = $result->{'DSLServiceId'};

  $result = $self->ikano_command('ACCOUNTSTATUSCHANGE',
	{ DSLPhoneNumber => $svc_dsl->phonenum,
	  DSLServiceId => $DSLServiceId,
	  type => $type,
	} ); 
  return $result unless ref($result); # scalar (string) is an error
  ''; 
}

sub _export_suspend {
  my( $self, $svc_dsl ) = (shift, shift);
  $self->statuschg($svc_dsl,"SUSPEND");
}

sub _export_unsuspend {
  my( $self, $svc_dsl ) = (shift, shift);
  $self->statuschg($svc_dsl,"UNSUSPEND");
}

1;
