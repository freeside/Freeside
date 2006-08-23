%
%
%#untaint paynum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal paynum";
%my $paynum = $1;
%
%my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } );
%my $custnum = $cust_pay->custnum;
%
%foreach my $cust_bill_pay ( $cust_pay->cust_bill_pay ) {
%  my $error = $cust_bill_pay->delete;
%  eidiot($error) if $error;
%}
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

