% if ( $error ) {
%   $cgi->param('error', $error);
% }
<% $cgi->redirect(popurl(3)."search/cust_pay_batch.cgi?dcln=1;batchnum=$batchnum") %>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Process batches');

my $batchnum = $cgi->param('batchnum');
# make a record in the paybatch of who did this
my $paybatch = 'manual-'.$FS::CurrentUser::CurrentUser->username.
   '-' . time2str('%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);
my $pay_batch = qsearchs('pay_batch', { 'batchnum' => $batchnum })
  or die "batchnum '$batchnum' not found";
my $error = $pay_batch->manual_approve('paybatch' => $paybatch);
</%init>
