<%

my $error = '';

#unmunge stuff

$cgi->param('tax','') unless defined $cgi->param('tax');

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

my $payby = $cgi->param('payby');
if ( $payby ) {
  if ( $payby eq 'CHEK' ) {
    $cgi->param('payinfo',
      $cgi->param('CHEK_payinfo1'). '@'. $cgi->param('CHEK_payinfo2') );
  } else {
    $cgi->param('payinfo', $cgi->param( $payby. '_payinfo' ) );
  }
  $cgi->param('paydate',
    $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' ) );
  $cgi->param('payname', $cgi->param( $payby. '_payname' ) );
}

$cgi->param('otaker', &getotaker );

my @invoicing_list = split( /\s*\,\s*/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');
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

#perhaps this stuff should go to cust_main.pm
my $cust_pkg = '';
my $svc_acct = '';
if ( $new->custnum eq '' ) {

  if ( $cgi->param('pkgpart_svcpart') ) {
    my $x = $cgi->param('pkgpart_svcpart');
    $x =~ /^(\d+)_(\d+)$/;
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
    $error ||= "Agent ". $new->agentnum. " (type ". $agent->typenum. ") can't".
               "purchase pkgpart ". $pkgpart
      #unless $part_pkg{ $pkgpart };
      unless $pkgpart_href->{ $pkgpart };

    $cust_pkg = new FS::cust_pkg ( {
      #later         'custnum' => $custnum,
      'pkgpart' => $pkgpart,
    } );
    $error ||= $cust_pkg->check;

    #$cust_svc = new FS::cust_svc ( { 'svcpart' => $svcpart } );

    #$error ||= $cust_svc->check;

    $svc_acct = new FS::svc_acct ( {
                                     'svcpart'   => $svcpart,
                                     'username'  => $cgi->param('username'),
                                     '_password' => $cgi->param('_password'),
                                     'popnum'    => $cgi->param('popnum'),
                                   } );

    my $y = $svc_acct->setdefault; # arguably should be in new method
    $error ||= $y unless ref($y);
    #and just in case you were silly
    $svc_acct->svcpart($svcpart);
    $svc_acct->username($cgi->param('username'));
    $svc_acct->_password($cgi->param('_password'));
    $svc_acct->popnum($cgi->param('popnum'));

    $error ||= $svc_acct->check;

  } elsif ( $cgi->param('username') ) { #good thing to catch
    $error = "Can't assign username without a package!";
  }

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => [ $svc_acct ] ) if $cust_pkg;
  $error ||= $new->insert( \%hash, \@invoicing_list );
} else { #create old record object
  my $old = qsearchs( 'cust_main', { 'custnum' => $new->custnum } ); 
  $error ||= "Old record not found!" unless $old;
  $error ||= $new->replace($old, \@invoicing_list);
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_main.cgi?". $cgi->query_string );
} else { 
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?". $new->custnum);
} 
%>
