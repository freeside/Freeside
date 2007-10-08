%
%
%#untaint crednum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal crednum";
%my $crednum = $1;
%
%my $cust_credit = qsearchs('cust_credit',{'crednum'=>$crednum});
%my $custnum = $cust_credit->custnum;
%
%my $error = $cust_credit->delete;
%errorpage($error) if $error;
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

