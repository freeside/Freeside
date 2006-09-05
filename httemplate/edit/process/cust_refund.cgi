%$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
%my $custnum = $1;
%my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
%  or die "unknown custnum $custnum";
%
%my $error = '';
%if ( $cgi->param('payby') =~ /^(CARD|CHEK)$/ ) { 
%  my $bop = $FS::payby::payby2bop{$1};
%  $cgi->param('refund') =~ /^(\d*)(\.\d{2})?$/
%    or die "illegal refund amount ". $cgi->param('refund');
%  my $refund = "$1$2";
%  $cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
%  my $paynum = $1;
%  my $reason = $cgi->param('reason');
%  $error = $cust_main->realtime_refund_bop( $bop, 'amount' => $refund,
%                                                  'paynum' => $paynum,
%                                                  'reason' => $reason, );
%} else {
%  die 'unimplemented';
%  #my $new = new FS::cust_refund ( {
%  #  map {
%  #    $_, scalar($cgi->param($_));
%  #  } ( fields('cust_refund'), 'paynum' )
%  #} );
%  #$error = $new->insert;
%}
%
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). "cust_refund.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
%}
