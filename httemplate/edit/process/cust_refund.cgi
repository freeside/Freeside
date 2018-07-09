%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "cust_refund.cgi?". $cgi->query_string ) %>
%} else {
%
%  if ( $link eq 'popup' ) {
%
<% header('Refund entered') %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
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

my $conf = new FS::Conf;

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

  my %payby2fields = (
  'CARD' => [ qw( address1 address2 city county state zip country ) ],
  'CHEK' => [ qw( ss paytype paystate stateid stateid_state ) ],
  );
  my %type = ( 'CARD' => 'credit card',
             'CHEK' => 'electronic check (ACH)',
             );

##
# now run the refund
##

  $cgi->param('refund') =~ /^(\d*)(\.\d{2})?$/
    or die "illegal refund amount ". $cgi->param('refund');
  my $refund = "$1$2";
  $cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
  my $paynum = $1;
  #my $paydate;
  my $paydate = $cgi->param('exp_year'). '-'. $cgi->param('exp_month'). '-01';
  #unless ($paynum) {
  #  if ($cust_payby->paydate) { $paydate = "$year-$month-01"; }
  #  else { $paydate = "2037-12-01"; }
  #}

  if ( $cgi->param('batch') ) {
    $paydate = "2037-12-01" unless $paydate;
    $error ||= $cust_main->batch_card(
                                     'payby'    => $payby,
                                     'amount'   => $refund,
                                     #'payinfo'  => $payinfo,
                                     #'paydate'  => $paydate,
                                     #'payname'  => $payname,
                                     'paycode'  => 'C',
                                     map { $_ => scalar($cgi->param($_)) }
                                       @{$payby2fields{$payby}}
                                   );
    errorpage($error) if $error;

    my %hash = map {
      $_, scalar($cgi->param($_))
    } fields('cust_refund');

    my $new = new FS::cust_refund ( { 'paynum' => $paynum,
                                      %hash,
                                  } );
    $error = $new->insert;

  # if not a batch refund run realtime.
  } else {
    $options{'paydate'} = $paydate if $paydate =~ /^\d{2,4}-\d{1,2}-01$/;
    $error = $cust_main->realtime_refund_bop( $bop, 'amount' => $refund,
                                                  'paynum' => $paynum,
                                                  'reasonnum' => $reasonnum,
                                                  %options );
  }
} else { # run cash refund.
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
