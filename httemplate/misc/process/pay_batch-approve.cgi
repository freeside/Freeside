% if ( $error ) {
%   $cgi->param('error', $error);
% }
<% $cgi->redirect(popurl(3)."search/cust_pay_batch.cgi?dcln=1;batchnum=$batchnum") %>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Process batches');

my $batchnum = $cgi->param('batchnum');
my $paybatch = $batchnum;
my $usernum = $FS::CurrentUser::CurrentUser->usernum;
my $pay_batch = qsearchs('pay_batch', { 'batchnum' => $batchnum })
  or die "batchnum '$batchnum' not found";
my $error = $pay_batch->manual_approve(
  'paybatch' => $paybatch, 'usernum' => $usernum
);
</%init>
