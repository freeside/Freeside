%if ( $error ) {
%  errorpage($error);
%} else {
%  my $cookie = CGI::Cookie->new( -name    => 'freeside_status',
%                                 -value   => mt('Package unsuspended'),
%                                 -expires => '+5m',
%                               );
% #$r->headers_out->add( 'Set-Cookie' => $cookie->as_string );
<% $cgi->redirect(
     -uri => popurl(2). "view/cust_main.cgi?show=packages;custnum=".$cust_pkg->getfield('custnum'),
     -cookie => $cookie
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

</%init>
