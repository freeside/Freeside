<% $cgi->redirect("${p}view/cust_main.cgi?$custnum") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $template = $2;
my $invnum = $3;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

$cust_bill->fax_invoice($template);

my $custnum = $cust_bill->getfield('custnum');

</%init>
