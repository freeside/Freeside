%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "cust_refund.cgi?". $cgi->query_string ) %>
%} else {
%
%  if ( $link eq 'popup' ) {
%
<& /elements/header-popup.html, 'Refund entered' &>
    <SCRIPT TYPE="text/javascript">
      topreload();
    </SCRIPT>

    </BODY></HTML>
%  } else {
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?custnum=$custnum;show=payment_history") %>
%  }
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Refund payment')
      || $FS::CurrentUser::CurrentUser->access_right('Post refund');

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
my $custnum = $1;
my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
  or die "unknown custnum $custnum";

my $link    = $cgi->param('popup') ? 'popup' : '';

my $payby = $cgi->param('payby');

die "access denied"
  unless $FS::CurrentUser::CurrentUser->refund_access_right($payby);

$cgi->param('reasonnum') =~ /^(-?\d+)$/ or die "Illegal reasonnum";
my ($reasonnum, $error) = $m->comp('/misc/process/elements/reason');
$cgi->param('reasonnum', $reasonnum) unless $error;

if ( $error ) {
  # do nothing
} elsif ( $payby =~ /^(CARD|CHEK)$/ ) { 
  my %options = ();
  my $bop = $FS::payby::payby2bop{$1};
  $cgi->param('refund') =~ /^(\d*)(\.\d{2})?$/
    or die "illegal refund amount ". $cgi->param('refund');
  my $refund = "$1$2";
  $cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
  my $paynum = $1;
  my $paydate = $cgi->param('exp_year'). '-'. $cgi->param('exp_month'). '-01';
  $options{'paydate'} = $paydate if $paydate =~ /^\d{2,4}-\d{1,2}-01$/;
  $error = $cust_main->realtime_refund_bop( $bop, 'amount' => $refund,
                                                  'paynum' => $paynum,
                                                  'reasonnum' => scalar($cgi->param('reasonnum')),
                                                  %options );
} else {
  my %hash = map {
    $_, scalar($cgi->param($_))
  } fields('cust_refund');
  my $paynum = $cgi->param('paynum');
  $paynum =~ /^(\d*)$/ or die "Illegal paynum!";
  if ($paynum) {
    my $cust_pay = qsearchs('cust_pay',{ 'paynum' => $paynum });
    die "Could not find paynum $paynum" unless $cust_pay;
    $error = $cust_pay->refund(\%hash);
  } else {
    my $new = new FS::cust_refund ( \%hash );
    $error = $new->insert;
  }
}

</%init>
