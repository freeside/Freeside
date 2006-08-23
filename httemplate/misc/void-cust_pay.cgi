%
%
%#untaint paynum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal paynum";
%my $paynum = $1;
%
%my $cust_pay = qsearchs('cust_pay',{'paynum'=>$paynum});
%my $custnum = $cust_pay->custnum;
%
%my $error = $cust_pay->void;
%eidiot($error) if $error;
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

