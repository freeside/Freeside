%
%
%#untaint refundnum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal refundnum";
%my $refundnum = $1;
%
%my $cust_refund = qsearchs('cust_refund',{'refundnum'=>$refundnum});
%my $custnum = $cust_refund->custnum;
%
%my $error = $cust_refund->delete;
%eidiot($error) if $error;
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

