<!-- $Id: delete-cust_pay.cgi,v 1.1 2002-02-07 22:29:35 ivan Exp $ -->
<%

#untaint paynum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal paynum";
my $paynum = $1;

my $cust_pay = qsearchs('cust_pay',{'paynum'=>$paynum});
my $custnum = $cust_pay->custnum;

my $error = $cust_pay->delete;
eidiot($error) if $error;

print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);

%>
