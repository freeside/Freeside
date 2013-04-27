%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2)) %>
%}

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unprovision customer service')
      && $FS::CurrentUser::CurrentUser->access_right('View/link unlinked services');

#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;

my $error = '';
my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
if ( $cust_svc ) {
  my $cust_pkg = $cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    errorpage( 'This account has already been audited.  Cancel the '.
             qq!<A HREF="${p}view/cust_main.cgi?!. $cust_pkg->custnum.
             '#cust_pkg'. $cust_pkg->pkgnum. '">'.
             'package</A> instead.'); #'
  }

  $error = $cust_svc->cancel;
} else {
  # the rare obscure case: svc_x without cust_svc
  my $svc_x;
  foreach my $svcdb (FS::part_svc->svc_tables) {
    $svc_x = qsearchs($svcdb, { 'svcnum' => $svcnum });
    last if $svc_x;
  }
  if ( $svc_x ) {
    $error = $svc_x->return_inventory
             || $svc_x->FS::Record::delete;
  } else {
    # the svcnum really doesn't exist
    $error = "svcnum $svcnum not found";
  }
}

</%init>
