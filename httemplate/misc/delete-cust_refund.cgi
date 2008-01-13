% if ( $error ) {
%   errorpage($error);
% } else {
<% $cgi->redirect($p. "view/cust_main.cgi?". $custnum) %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Delete refund');

#untaint refundnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal refundnum";
my $refundnum = $1;

my $cust_refund = qsearchs('cust_refund',{'refundnum'=>$refundnum});
my $custnum = $cust_refund->custnum;

my $error = $cust_refund->delete;

</%init>
