%
%
%#untaint crednum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal crednum";
%my $crednum = $1;
%
%my $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } );
%my $custnum = $cust_credit->custnum;
%
%foreach my $cust_credit_bill ( $cust_credit->cust_credit_bill ) {
%  my $error = $cust_credit_bill->delete;
%  eidiot($error) if $error;
%}
%
%print $cgi->redirect($p. "view/cust_main.cgi?". $custnum);
%
%

