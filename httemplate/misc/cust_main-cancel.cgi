%
%
%my $custnum;
%my $ban = '';
%if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
%  $custnum = $1;
%  $ban = $cgi->param('ban');
%} else {
%  my($query) = $cgi->keywords;
%  $query =~ /^(\d+)$/ || die "Illegal custnum";
%  $custnum = $1;
%}
%
%my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
%
%my @errors = $cust_main->cancel( 'ban' => $ban );
%eidiot(join(' / ', @errors)) if scalar(@errors);
%
%#print $cgi->redirect($p. "view/cust_main.cgi?". $cust_main->custnum);
%print $cgi->redirect($p);
%
%

