<% $server->process %>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Process batches')
      || $curuser->access_right('Process global batches');

# look up paybatch using agentnums_sql & status constraints
# to validate access for this particular cust_pay_batch,
# similar to how it's done in cust_pay_batch.cgi

my %arg = $cgi->param('arg');
my $paybatchnum = $arg{'paybatchnum'};
$paybatchnum =~ /^\d+$/ or die "Illegal paybatchnum";
my @search = ();
push @search, 'cust_pay_batch.paybatchnum = ' . $paybatchnum;
push @search, '(cust_pay_batch.status = \'\' OR cust_pay_batch.status IS NULL)';
push @search, 'pay_batch.status = \'O\'';
push @search, $curuser->agentnums_sql({ table => 'cust_main' });
push @search, $curuser->agentnums_sql({ table      => 'pay_batch',
                                        null_right => 'Process global batches',
                                     });
my $search = ' WHERE ' . join(' AND ', @search);
die "permission denied" unless qsearchs({
  'table'     => 'cust_pay_batch',
  'hashref'   => {},
  'addl_from' => 'LEFT JOIN pay_batch USING ( batchnum ) '.
                 'LEFT JOIN cust_main USING ( custnum ) '.
                 'LEFT JOIN cust_pay  USING ( batchnum, custnum ) ',
  'extra_sql' => $search
});

my $server = new FS::UI::Web::JSRPC 'FS::cust_pay_batch::process_unbatch_and_delete', $cgi; 

</%init>
