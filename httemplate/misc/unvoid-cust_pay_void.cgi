%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect($p. "view/cust_main.cgi?". $custnum) %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unvoid payments');

#untaint paynum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal paynum";
my $paynum = $1;

my $cust_pay_void = qsearchs('cust_pay_void', { 'paynum' => $paynum } );
my $custnum = $cust_pay_void->custnum;

my $error = $cust_pay_void->unvoid;

</%init>
