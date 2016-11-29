%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(
     -uri    => popurl(2). "view/cust_main.cgi?show=packages;custnum=$custnum",
     -cookie => CGI::Cookie->new( -name    => 'freeside_status',
                                  -value   => mt('Package unsuspended'),
                                  -expires => '+5m',
                                ),
   )
%>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unsuspend customer package');

#untaint pkgnum
my ($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal pkgnum";
my $pkgnum = $1;

my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

my $error = $cust_pkg->unsuspend;

my $custnum = $cust_pkg->custnum;

</%init>
