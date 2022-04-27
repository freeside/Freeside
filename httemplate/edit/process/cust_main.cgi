% if ( $error ) {
%   $cgi->param('error', $error);
%   # workaround for create_uri_query's mangling of unicode characters,
%   # false laziness with FS::Record::ut_coord
%   use charnames ':full';
%   for my $pre (qw(bill ship)) {
%     foreach (qw( latitude longitude)) {
%       my $coord = $cgi->param($pre.'_'.$_);
%       $coord =~ s/\N{DEGREE SIGN}\s*$//;
%       $cgi->param($pre.'_'.$_, $coord);
%     }
%   }
%   my $query = $m->scomp('/elements/create_uri_query', 'secure'=>1);
<% $cgi->redirect(popurl(2). "cust_main.cgi?$query" ) %>
%
% } else { 
%
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?". $new->custnum) %>
%
% }
<%once>

my $me = '[edit/process/cust_main.cgi]';
my $DEBUG = 0;

</%once>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied" unless $curuser->access_right('Edit customer');

my $conf = new FS::Conf;

my $error = '';

#unmunge stuff

$cgi->param('tax','') unless defined $cgi->param('tax');

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

my $payby = $cgi->param('payby');

my %noauto = (
  'CARD' => 'DCRD',
  'CHEK' => 'DCHK',
);
$payby = $noauto{$payby}
  if ! $cgi->param('payauto') && exists $noauto{$payby};

$cgi->param('payby', $payby);

if ( $payby ) {
  if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {
      my $payinfo = $cgi->param('payinfo1'). '@';
      $payinfo .= $cgi->param('payinfo3').'.' 
            if $conf->config('echeck-country') eq 'CA';
      $payinfo .= $cgi->param('payinfo2');
      $cgi->param('payinfo',$payinfo);
  }
  $cgi->param('paydate',
    $cgi->param( 'exp_month' ). '-'. $cgi->param( 'exp_year' ) );
}

my @invoicing_list = split( /[,\s]+/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');
push @invoicing_list, 'FAX' if $cgi->param('invoicing_list_FAX');
$cgi->param('invoicing_list', join(',', @invoicing_list) );

# is this actually used?  if so, we need to clone locations...
# but I can't find anything that sets this parameter to a non-empty value
# yes, fec48523d3cf056da08813f9b2b7d633b27aaf8d for #16582 is where it came in,
# for "duplicate address checking for new customers".  afaict still in
# edit/cust_main/bottomfixup.html (and working?)
$cgi->param('duplicate_of_custnum') =~ /^(\d+)$/;
my $duplicate_of = $1;

# if this is enabled, enforce it
if ( $conf->exists('agent-ship_address', scalar($cgi->param('agentnum'))) ) {
  my $agent = FS::agent->by_key($cgi->param('agentnum'));
  my $agent_cust_main = $agent->agent_cust_main;
  if ( $agent_cust_main ) {
    my $agent_location = $agent_cust_main->ship_location;
    foreach (qw(address1 city state zip country latitude longitude district)) {
      $cgi->param("ship_$_", $agent_location->get($_));
    }
  }
}

my %locations;
for my $pre (qw(bill ship)) {

  my %hash;
  foreach ( FS::cust_main->location_fields ) {
    $hash{$_} = scalar($cgi->param($pre.'_'.$_));
  }
  $hash{'custnum'} = $cgi->param('custnum');
  warn Dumper \%hash if $DEBUG;
  $locations{$pre} = FS::cust_location->new(\%hash);
}

if ( ($cgi->param('same') || '') eq 'Y' ) {
  $locations{ship} = $locations{bill};
}

#create new record object
# but explicitly avoid setting ship_ fields

my $new = new FS::cust_main ( {
  (map { ( $_, scalar($cgi->param($_)) ) } (fields('cust_main'))),
  (map { ( "ship_$_", '' ) } (FS::cust_main->location_fields))
} );

$new->invoice_noemail( ($cgi->param('invoice_email') eq 'Y') ? '' : 'Y' );

# add any virtual fields to the new cust_main record
foreach ($new->virtual_fields) {
  $new->setfield($_, scalar($cgi->param($_)));
}

if ( $duplicate_of ) {
  # then negate all changes to the customer; the only change we should
  # make is to order a package, if requested
  $new = qsearchs('cust_main', { 'custnum' => $duplicate_of })
  # this should never happen
    or die "nonexistent existing customer (custnum $duplicate_of)";
}

for my $pre (qw(bill ship)) {
  $new->set($pre.'_location', $locations{$pre});
  $new->set($pre.'_locationnum', $locations{$pre}->locationnum);
}

if ( $cgi->param('no_credit_limit') ) {
  $new->setfield('credit_limit', '');
}

$new->tagnum( [ $cgi->param('tagnum') ] );

$error ||= $new->set_national_id_from_cgi( $cgi );

my %usedatetime = ( 'birthdate'        => 1,
                    'spouse_birthdate' => 1,
                    'anniversary_date' => 1,
                  );

foreach my $dfield (qw(
  signupdate birthdate spouse_birthdate anniversary_date
)) {

  if ( $cgi->param($dfield) && $cgi->param($dfield) =~ /^([ 0-9\-\/]{0,10})$/) {

    my $value = $1;
    my $parsed = '';

    if ( exists $usedatetime{$dfield} && $usedatetime{$dfield} ) {

      my $format = $conf->config('date_format') || "%m/%d/%Y";
      my $parser = DateTime::Format::Strptime->new( pattern   => $format,
                                                    time_zone => 'floating',
                                                  );
      my $dt = $parser->parse_datetime($value);
      if ( $dt ) {
        $parsed = $dt->epoch;
      } else {
        $error ||= "Invalid $dfield: $value";
      }

    } else {

      $parsed = parse_datetime($value)
        or $error ||= "Invalid $dfield: $value";

    }

    $new->setfield( $dfield, $parsed );
    $cgi->param(    $dfield, $parsed );

  }

}

$new->setfield('paid', $cgi->param('paid') )
  if $cgi->param('paid');

my %options = ();
if ( $curuser->access_right('Edit customer tax exemptions') ) { 
  my @exempt_groups = grep /\S/, $conf->config('tax-cust_exempt-groups');
  my @tax_exempt = grep { $cgi->param("tax_$_") eq 'Y' } @exempt_groups;
  $options{'tax_exemption'} = {
    map { $_ => scalar($cgi->param("tax_$_".'_num')) } @tax_exempt
  };
}

#perhaps this stuff should go to cust_main.pm
if ( $new->custnum eq '' or $duplicate_of ) {

  my $cust_pkg = '';
  my $svc;

  if ( $cgi->param('pkgpart_svcpart') ) {

    my $x = $cgi->param('pkgpart_svcpart');
    $x =~ /^(\d+)_(\d+)$/ or die "illegal pkgpart_svcpart $x\n";
    my($pkgpart, $svcpart) = ($1, $2);
    my $part_pkg = qsearchs('part_pkg', { 'pkgpart' => $pkgpart } );
    #false laziness: copied from FS::cust_pkg::order (which should become a
    #FS::cust_main method)
    my(%part_pkg);
    # generate %part_pkg
    # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    my $agent = qsearchs('agent',{'agentnum'=> $new->agentnum });

    if ( $agent ) {
      # $pkgpart_href->{PKGPART} is true iff $custnum may purchase $pkgpart
      my $pkgpart_href = $agent->pkgpart_hashref
        if $agent;
      #eslaf

      # this should wind up in FS::cust_pkg!
      $error ||= "Agent ". $new->agentnum. " (type ". $agent->typenum.
                 ") can't purchase pkgpart ". $pkgpart
        #unless $part_pkg{ $pkgpart };
        unless $pkgpart_href->{ $pkgpart }
            || $agent->agentnum == $part_pkg->agentnum;
    } else {
      $error = 'Select agent';
    }

    $cust_pkg = new FS::cust_pkg ( {
      #later         'custnum' => $custnum,
      'pkgpart'     => $pkgpart,
      'locationnum' => scalar($cgi->param('locationnum')),
      'salesnum'    => scalar($cgi->param('salesnum')),
    } );


    my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
    my $svcdb = $part_svc->svcdb;

    if ( $svcdb eq 'svc_acct' ) {

      my %svc_acct = (
                       'svcpart'   => $svcpart,
                       'username'  => scalar($cgi->param('username')),
                       '_password' => scalar($cgi->param('_password')),
                       'popnum'    => scalar($cgi->param('popnum')),
                     );
      $svc_acct{'domsvc'} = $cgi->param('domsvc')
        if $cgi->param('domsvc');

      $svc = new FS::svc_acct \%svc_acct;

      #and just in case you were silly
      $svc->svcpart($svcpart);
      $svc->username($cgi->param('username'));
      $svc->_password($cgi->param('_password'));
      $svc->popnum($cgi->param('popnum'));

    } elsif ( $svcdb eq 'svc_phone' ) {

      my %svc_phone = (
        'svcpart' => $svcpart,
        map { $_ => scalar($cgi->param($_)) }
            qw( countrycode phonenum sip_password pin phone_name )
      );

      $svc = new FS::svc_phone \%svc_phone;

    } elsif ( $svcdb eq 'svc_dsl' ) {

      my %svc_dsl = (
        'svcpart' => $svcpart,
        ( map { $_ => scalar($cgi->param("ship_$_")) || scalar($cgi->param($_))}
              qw( first last company )
        ),
        ( map { $_ => scalar($cgi->param($_)) }
              qw( loop_type phonenum password isp_chg isp_prev vendor_qual_id )
        ),
        'desired_due_date'  => time, #XXX enter?
        'vendor_order_type' => 'NEW',
      );
      $svc = new FS::svc_dsl \%svc_dsl;

    } else {
      die "$svcdb not handled on new customer yet";
    }

  }


  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => [ $svc ] ) if $cust_pkg;
  if ( $duplicate_of ) {
    # order the package and service normally
    $error ||= $new->order_pkgs( \%hash ) if $cust_pkg;
  }
  else {
    # create the customer
    $error ||= $new->insert( \%hash, \@invoicing_list,
                             %options,
                             prospectnum => scalar($cgi->param('prospectnum')),
                           );

    my $conf = new FS::Conf;
    if ( $conf->exists('backend-realtime') && ! $error ) {

      my $berror =    $new->bill
                   || $new->apply_payments_and_credits
                   || $new->collect( 'realtime' => 1 );
      warn "Warning, error billing during backend-realtime: $berror" if $berror;

    }
  } #if $duplicate_of
  
} else { #create old record object

  my $old = qsearchs( 'cust_main', { 'custnum' => $new->custnum } ); 
  $error ||= "Old record not found!" unless $old;

  if ( length($old->paycvv) && $new->paycvv =~ /^\s*\*+\s*$/ ) {
    $new->paycvv($old->paycvv);
  }
  if ($new->ss =~ /xx/) {
    $new->ss($old->ss);
  }
  if ($new->stateid =~ /^xxx/) {
    $new->stateid($old->stateid);
  }
  if ( $new->payby =~ /^(CARD|DCRD)$/
       && (    $new->payinfo =~ /xx/
            || $new->payinfo =~ /^\s*N\/A\s+\(tokenized\)\s*$/
          )
     )
  {
    $new->payinfo($old->payinfo);
    $new->paymask($old->paymask) if ! $new->paymask || $new->paymask =~ /^N\/A/;

  } elsif ( $new->payby =~ /^(CHEK|DCHK)$/ && $new->payinfo =~ /xx/ ) {
    #fix for #3085 "edit of customer's routing code only surprisingly causes
    #nothing to happen...
    # this probably won't do the right thing when we don't have the
    # public key (can't actually get the real $old->payinfo)
    my($new_account, $new_aba) = split('@', $new->payinfo);
    my($old_account, $old_aba) = split('@', $old->payinfo);
    $new_account = $old_account if $new_account =~ /xx/;
    $new_aba     = $old_aba     if $new_aba     =~ /xx/;
    $new->payinfo($new_account.'@'.$new_aba);
  }

  if ( ! $conf->exists('cust_main-edit_signupdate') or
       ! $new->signupdate ) {
    $new->signupdate($old->signupdate);
  }

  warn "$me calling $new -> replace( $old, \ @invoicing_list )" if $DEBUG;
  local($FS::cust_main::DEBUG) = $DEBUG if $DEBUG;
  local($FS::Record::DEBUG)    = $DEBUG if $DEBUG;

  local($Data::Dumper::Sortkeys) = 1;
  warn Dumper({ new => $new, old => $old }) if $DEBUG;

  $error ||= $new->replace( $old, \@invoicing_list,
                            %options,
                          );

  warn "$me returned from replace" if $DEBUG;
  
}

unless ( $error ) { #XXX i should be transactional... all in the insert
                    # or replace call

  $error = $new->process_o2m( 'table'  => 'contact',
                              'fields' => FS::contact->cgi_contact_fields,
                              'params' => scalar($cgi->Vars),
                            );
}

</%init>
