<% $cgi->redirect($p. "view/cust_main.cgi?custnum=". $custnum. ";show=payment_history") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unapply credit');

#untaint crednum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal crednum";
my $crednum = $1;

my $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } );
my $custnum = $cust_credit->custnum;

my $error = $cust_credit->unapply_refund;
errorpage($error) if $error;

</%init>
