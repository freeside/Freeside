%if ( $error ) {
%  $cgi->param('error', $error);
%  $dbh->rollback if $oldAutoCommit;
%  
<% $cgi->redirect(popurl(2). "cust_credit.cgi?". $cgi->query_string ) %>
%
%} else {
%
%  if ( $cgi->param('apply') eq 'yes' ) {
%    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum })
%      or die "unknown custnum $custnum";
%    $cust_main->apply_credits;
%  }
%
%  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
%  
<% header(emt('Credit successful')) %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>

  </BODY></HTML>
% } 
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Post credit');

$cgi->param('custnum') =~ /^(\d+)$/ or die "Illegal custnum!";
my $custnum = $1;

$cgi->param('reasonnum') =~ /^(-?\d+)$/ or die "Illegal reasonnum";
my $reasonnum = $1;

my $oldAutoCommit = $FS::UID::AutoCommit;
local $FS::UID::AutoCommit = 0;
my $dbh = dbh;

my ($reasonnum, $error) = $m->comp('/misc/process/elements/reason');
if (!$reasonnum) {
  $error ||= 'Reason required'
}
$cgi->param('reasonnum', $reasonnum) unless $error;

unless ($error) {
  my $new = new FS::cust_credit ( {
    map {
      $_, scalar($cgi->param($_));
    } fields('cust_credit')
  } );
  $error = $new->insert;
}

</%init>
