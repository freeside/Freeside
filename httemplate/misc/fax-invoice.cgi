<%

my $conf = new FS::Conf;
my $lpr = $conf->config('lpr');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $template = $2;
my $invnum = $3;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

my $error = &FS::Misc::send_fax(
  dialstring => $cust_bill->cust_main->getfield('fax'),
  docdata       => [ $cust_bill->print_ps('', $template) ],
);

die $error if $error;

my $custnum = $cust_bill->getfield('custnum');

print $cgi->redirect("${p}view/cust_main.cgi?$custnum");

%>
