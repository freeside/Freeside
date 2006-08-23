%
%
%#untaint invnum
%my($query) = $cgi->keywords;
%$query =~ /^((.+)-)?(\d+)$/;
%my $template = $2;
%my $invnum = $3;
%my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
%die "Can't find invoice!\n" unless $cust_bill;
%
%$cust_bill->fax($template);
%
%my $custnum = $cust_bill->getfield('custnum');
%
%print $cgi->redirect("${p}view/cust_main.cgi?$custnum");
%
%

