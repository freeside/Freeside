%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'misc/order_pkg.html?'. $cgi->query_string ) %>
%} else {
%  my $frag = "cust_pkg". $cust_pkg[0]->pkgnum;
<% header('Package ordered') %>
  <SCRIPT TYPE="text/javascript">
    // XXX fancy ajax rebuild table at some point, but a page reload will do for now

    // XXX chop off trailing #target and replace... ?
    window.top.location = '<% popurl(3). "view/cust_main.cgi?keywords=$custnum;fragment=$frag#$frag" %>';

  </SCRIPT>

  </BODY></HTML>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Order customer package');

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/
  or die 'illegal custnum '. $cgi->param('custnum');
my $custnum = $1;
$cgi->param('pkgpart') =~ /^(\d+)$/
  or die 'illegal pkgpart '. $cgi->param('pkgpart');
my $pkgpart = $1;

my @cust_pkg = ();
my $error = FS::cust_pkg::order($custnum, [ $pkgpart ], [], \@cust_pkg, [ $cgi->param('refnum') ] );

</%init>
