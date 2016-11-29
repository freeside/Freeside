<%init>
my $DEBUG = 0;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Post payment batch');

my $param = $cgi->Vars;
warn Dumper($param) if $DEBUG;

#my $paybatch = $param->{'paybatch'};
my $paybatch = time2str('webbatch-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);

my @cust_pay = ();
#my $row = 0;
#while ( exists($param->{"custnum$row"}) ) {
my @invrows = grep(/^invnum\d+\.\d+$/, keys %$param);
foreach my $row ( map /^custnum(\d+)$/, keys %$param ) {
  my $custnum = $param->{"custnum$row"};
  my $cust_main;
  if ( $custnum =~ /^(\d+)$/ and $1 <= 2147483647 ) {
    $cust_main = qsearchs({ 
      'table'     => 'cust_main',
      'hashref'   => { 'custnum' => $1 },
      'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
    });
  }
  if ( length($custnum) and !$cust_main ) { # not found, try agent_custid
    $cust_main = qsearchs({ 
      'table'     => 'cust_main',
      'hashref'   => { 'agent_custid' => $custnum },
      'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
    });
  }
  $custnum = $cust_main->custnum if $cust_main;
  # if !$cust_main, then this will throw an error on batch_insert

  my $cust_pay = new FS::cust_pay {
                    'custnum'        => $custnum,
                    'paid'           => $param->{"paid$row"},
                    'payby'          => 'BILL',
                    'payinfo'        => $param->{"payinfo$row"},
                    '_date'          => $param->{"_date$row"},
                    'discount_term'  => $param->{"discount_term$row"},
                    'paybatch'       => $paybatch,
                    'no_auto_apply'  => exists($param->{"no_auto_apply$row"}) ? 'Y' : '',
                  }
    if    $param->{"custnum$row"}
       || $param->{"paid$row"}
       || $param->{"payinfo$row"};
  next if !$cust_pay;
  #$row++;

  # payment applications, if any
  my @cust_bill_pay = ();
  foreach my $app ( sort {$a <=> $b} map /^invnum$row\.(\d+)$/, @invrows ) {
#  for ( my $app = 0; exists($param->{"invnum$row.$app"}); $app++ ) {
    next if !$param->{"invnum$row.$app"};
    push @cust_bill_pay, new FS::cust_bill_pay {
                            'invnum'  => $param->{"invnum$row.$app"},
                            'amount'  => $param->{"amount$row.$app"}
                          };
  }
  $cust_pay->set('apply_to', \@cust_bill_pay) if scalar(@cust_bill_pay) > 0;

  push @cust_pay, $cust_pay;

}

my @errors = FS::cust_pay->batch_insert(@cust_pay);
my $num_errors = scalar(grep $_, @errors);
</%init>
%  if ( $num_errors ) {
%
%    $cgi->param('error', "$num_errors error". ($num_errors>1 ? 's' : '').
%                         ' - Batch not processed, correct and resubmit'
%               );
%
%    my $erow=0;
%    $cgi->param('error'. $erow++, shift @errors) while @errors;
%    
%    my $query = $m->scomp('/elements/create_uri_query');
%
<% $cgi->redirect($p."batch-cust_pay.html?$query")

  %>
% } else {
%
%    
<% $cgi->redirect(popurl(3). "search/cust_pay.html?magic=paybatch;paybatch=$paybatch") %>
% } 
