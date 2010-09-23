%  die "access denied"
%    unless $FS::CurrentUser::CurrentUser->access_right('Post payment batch');
%
%  my $param = $cgi->Vars;
%
%  #my $paybatch = $param->{'paybatch'};
%  my $paybatch = time2str('webbatch-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);
%
%  my @cust_pay = ();
%  #my $row = 0;
%  #while ( exists($param->{"custnum$row"}) ) {
%  for ( my $row = 0; exists($param->{"custnum$row"}); $row++ ) {
%    my $custnum = $param->{"custnum$row"};
%    my $cust_main;
%    if ( $custnum =~ /^(\d+)$/ and $1 <= 2147483647 ) {
%      $cust_main = qsearchs({ 
%        'table'     => 'cust_main',
%        'hashref'   => { 'custnum' => $1 },
%        'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%      });
%    }
%    if ( !$cust_main ) { # not found, try agent_custid
%      $cust_main = qsearchs({ 
%        'table'     => 'cust_main',
%        'hashref'   => { 'agent_custid' => $custnum },
%        'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%      });
%    }
%    $custnum = $cust_main->custnum if $cust_main;
%    # if !$cust_main, then this will throw an error on batch_insert
%
%    push @cust_pay, new FS::cust_pay {
%                      'custnum'        => $custnum,
%                      'paid'           => $param->{"paid$row"},
%                      'payby'          => 'BILL',
%                      'payinfo'        => $param->{"payinfo$row"},
%                      'discount_term'  => $param->{"discount_term$row"},
%                      'paybatch'       => $paybatch,
%                    }
%      if    $param->{"custnum$row"}
%         || $param->{"paid$row"}
%         || $param->{"payinfo$row"};
%    #$row++;
%  }
%
%  my @errors = FS::cust_pay->batch_insert(@cust_pay);
%  my $num_errors = scalar(grep $_, @errors);
%
%  if ( $num_errors ) {
%
%    $cgi->param('error', "$num_errors error". ($num_errors>1 ? 's' : '').
%                         ' - Batch not processed, correct and resubmit'
%               );
%
%    my $erow=0;
%    $cgi->param('error'. $erow++, shift @errors) while @errors;
%
%    
<% $cgi->redirect($p.'batch-cust_pay.html?'. $cgi->query_string)

  %>
% } else {
%
%    
<% $cgi->redirect(popurl(3). "search/cust_pay.html?magic=paybatch;paybatch=$paybatch") %>
% } 

