%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect($p. "view/cust_main.cgi?custnum=". $custnum .";show=payment_history") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unvoid credit');

#untaint crednum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal crednum";
my $crednum = $1;

my $cust_credit_void = qsearchs('cust_credit_void', { 'crednum' => $crednum } );
my $custnum = $cust_credit_void->custnum;

my $error = $cust_credit_void->unvoid;

</%init>
