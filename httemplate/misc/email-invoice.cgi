<%

my $conf = new FS::Conf;

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $template = $2;
my $invnum = $3;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

my $error = send_email(
  $cust_bill->generate_email(
    'from'     => 
      ( $cust_bill->_agent_invoice_from || $conf->config('invoice_from') ),
    'template' => $template,
  )
);
eidiot($error) if $error;

my $custnum = $cust_bill->getfield('custnum');
print $cgi->redirect("${p}view/cust_main.cgi?$custnum");

%>
