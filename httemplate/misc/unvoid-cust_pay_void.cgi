%
%
%#untaint paynum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal paynum";
%my $paynum = $1;
%
%my $cust_pay_void = qsearchs('cust_pay_void', { 'paynum' => $paynum } );
%my $custnum = $cust_pay_void->custnum;
%
%my $error = $cust_pay_void->unvoid;
%errorpage($error) if $error;
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

