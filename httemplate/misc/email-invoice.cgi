<%

my $conf = new FS::Conf;

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d*)$/;
my $invnum = $1;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

my $error = send_email(
  'from'    => $cust_bill->_agent_invoice_from || $conf->config('invoice_from'),
  'to'      => [ grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ],
  'subject' => 'Invoice',
  'body'    => [ $cust_bill->print_text ],
);
eidiot($error) if $error;

my $custnum = $cust_bill->getfield('custnum');
print $cgi->redirect("${p}view/cust_main.cgi?$custnum");

%>
