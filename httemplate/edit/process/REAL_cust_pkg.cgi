%
%
%my $pkgnum = $cgi->param('pkgnum') or die;
%my $old = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
%my %hash = $old->hash;
%$hash{'setup'} = $cgi->param('setup') ? str2time($cgi->param('setup')) : '';
%$hash{'bill'} = $cgi->param('bill') ? str2time($cgi->param('bill')) : '';
%$hash{'last_bill'} =
%  $cgi->param('last_bill') ? str2time($cgi->param('last_bill')) : '';
%$hash{'expire'} = $cgi->param('expire') ? str2time($cgi->param('expire')) : '';
%
%my $new;
%my $error;
%if ( $hash{'bill'} != $old->bill        # if the next bill date was changed
%     && $hash{'bill'} < time            # to a date in the past
%     && ! $cgi->param('bill_areyousure') # and it wasn't confirmed
%   )
%{
%  $error = '_bill_areyousure';
%} else {
%  $new = new FS::cust_pkg \%hash;
%  $error = $new->replace($old);
%}
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). "REAL_cust_pkg.cgi?". $cgi->query_string );
%} else { 
%  my $custnum = $new->custnum;
%  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum".
%                       "#cust_pkg$pkgnum" );
%}
%
%

