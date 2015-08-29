<% $cgi->redirect($p. "view/cust_main.cgi?". $custnum) %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unapply payment');

#untaint paynum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal paynum";
my $paynum = $1;

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } );
my $custnum = $cust_pay->custnum;

my $error = $cust_pay->delete_cust_bill_pay;
errorpage($error) if $error;

</%init>
