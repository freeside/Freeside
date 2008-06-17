% if ( $error ) {
%   $cgi->param('error', $error);
%
<% $cgi->redirect(popurl(2). "cust_main.cgi?". $cgi->query_string ) %>
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

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit customer');

my $error = '';

#unmunge stuff

$cgi->param('tax','') unless defined $cgi->param('tax');

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

#my $payby = $cgi->param('payby');
my $payby = $cgi->param('select'); # XXX key

my %noauto = (
  'CARD' => 'DCRD',
  'CHEK' => 'DCHK',
);
$payby = $noauto{$payby}
  if ! $cgi->param('payauto') && exists $noauto{$payby};

$cgi->param('payby', $payby);

if ( $payby ) {
  if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {
    $cgi->param('payinfo',
      $cgi->param('payinfo1'). '@'. $cgi->param('payinfo2') );
  }
  $cgi->param('paydate',
    $cgi->param( 'exp_month' ). '-'. $cgi->param( 'exp_year' ) );
}

my @invoicing_list = split( /\s*\,\s*/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');
push @invoicing_list, 'FAX' if $cgi->param('invoicing_list_FAX');
$cgi->param('invoicing_list', join(',', @invoicing_list) );


#create new record object

my $new = new FS::cust_main ( {
  map {
    $_, scalar($cgi->param($_))
#  } qw(custnum agentnum last first ss company address1 address2 city county
#       state zip daytime night fax payby payinfo paydate payname tax
#       otaker refnum)
  } fields('cust_main')
} );

if ( defined($cgi->param('same')) && $cgi->param('same') eq "Y" ) {
  $new->setfield("ship_$_", '') foreach qw(
    last first company address1 address2 city county state zip
    country daytime night fax
  );
}

if ( $cgi->param('birthdate') && $cgi->param('birthdate') =~ /^([ 0-9\-\/]{0,10})$/) {
  my $conf = new FS::Conf;
  my $format = $conf->config('date_format') || "%m/%d/%Y";
  my $parser = DateTime::Format::Strptime->new(pattern => $format,
                                               time_zone => 'floating',
                                              );
  my $dt =  $parser->parse_datetime($1);
  if ($dt) {
    $new->setfield('birthdate', $dt->epoch);
    $cgi->param('birthdate', $dt->epoch);
  } else {
#    $error ||= $cgi->param('birthdate') . " is an invalid birthdate:" . $parser->errmsg;
    $error ||= "Invalid birthdate: " . $cgi->param('birthdate') . ".";
    $cgi->param('birthdate', '');
  }
}

$new->setfield('paid', $cgi->param('paid') )
  if $cgi->param('paid');

#perhaps this stuff should go to cust_main.pm
my $cust_pkg = '';
my $svc_acct = '';
if ( $new->custnum eq '' ) {

  if ( $cgi->param('pkgpart_svcpart') ) {
    my $x = $cgi->param('pkgpart_svcpart');
    $x =~ /^(\d+)_(\d+)$/ or die "illegal pkgpart_svcpart $x\n";
    my($pkgpart, $svcpart) = ($1, $2);
    #false laziness: copied from FS::cust_pkg::order (which should become a
    #FS::cust_main method)
    my(%part_pkg);
    # generate %part_pkg
    # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    my $agent = qsearchs('agent',{'agentnum'=> $new->agentnum });
    	#my($type_pkgs);
    	#foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
    	#  my($pkgpart)=$type_pkgs->pkgpart;
    	#  $part_pkg{$pkgpart}++;
    	#}
    # $pkgpart_href->{PKGPART} is true iff $custnum may purchase $pkgpart
    my $pkgpart_href = $agent->pkgpart_hashref;
    #eslaf

    # this should wind up in FS::cust_pkg!
    $error ||= "Agent ". $new->agentnum. " (type ". $agent->typenum. ") can't ".
               "purchase pkgpart ". $pkgpart
      #unless $part_pkg{ $pkgpart };
      unless $pkgpart_href->{ $pkgpart };

    $cust_pkg = new FS::cust_pkg ( {
      #later         'custnum' => $custnum,
      'pkgpart' => $pkgpart,
    } );
    #$error ||= $cust_pkg->check;

    #$cust_svc = new FS::cust_svc ( { 'svcpart' => $svcpart } );

    #$error ||= $cust_svc->check;

    my %svc_acct = (
                     'svcpart'   => $svcpart,
                     'username'  => $cgi->param('username'),
                     '_password' => $cgi->param('_password'),
                     'popnum'    => $cgi->param('popnum'),
                   );
    $svc_acct{'domsvc'} = $cgi->param('domsvc')
      if $cgi->param('domsvc');

    $svc_acct = new FS::svc_acct \%svc_acct;

    #and just in case you were silly
    $svc_acct->svcpart($svcpart);
    $svc_acct->username($cgi->param('username'));
    $svc_acct->_password($cgi->param('_password'));
    $svc_acct->popnum($cgi->param('popnum'));

    #$error ||= $svc_acct->check;

  } elsif ( $cgi->param('username') ) { #good thing to catch
    $error = "Can't assign username without a package!";
  }

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => [ $svc_acct ] ) if $cust_pkg;
  $error ||= $new->insert( \%hash, \@invoicing_list );

  my $conf = new FS::Conf;
  if ( $conf->exists('backend-realtime') && ! $error ) {

    my $berror =    $new->bill
                 || $new->apply_payments_and_credits
                 || $new->collect( 'realtime' => 1 );
    warn "Warning, error billing during backend-realtime: $berror" if $berror;

  }
  
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
  if ($new->payby =~ /^(CARD|DCRD)$/ && $new->payinfo =~ /xx/) {
    $new->payinfo($old->payinfo);
  } elsif ($new->payby =~ /^(CHEK|DCHK)$/ && $new->payinfo =~ /xx/) {
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

  warn "$me calling $new -> replace( $old, \ @invoicing_list )" if $DEBUG;
  local($FS::cust_main::DEBUG) = $DEBUG if $DEBUG;
  local($FS::Record::DEBUG)    = $DEBUG if $DEBUG;

  $error ||= $new->replace($old, \@invoicing_list);

  warn "$me returned from replace" if $DEBUG;
  
}

</%init>
