% if ( $error ) {
%   errorpage($error);
% } else {
<% $cgi->redirect($p. "view/cust_main.cgi?". $custnum) %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Delete credit');

#untaint crednum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal crednum";
my $crednum = $1;

my $cust_credit = qsearchs('cust_credit',{'crednum'=>$crednum});
my $custnum = $cust_credit->custnum;

my $error = $cust_credit->delete;

</%init>
