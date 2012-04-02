%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_pay.cgi?'. $cgi->query_string ) %>
%} elsif ( $field eq 'invnum' ) {
<% $cgi->redirect(popurl(3). "view/cust_bill.cgi?$linknum") %>
%} elsif ( $field eq 'custnum' ) {
%  if ( $cgi->param('apply') eq 'yes' ) {
%    my $cust_main = qsearchs('cust_main', { 'custnum' => $linknum })
%      or die "unknown custnum $linknum";
%    $cust_main->apply_payments( 'manual' => 1,
%                                'backdate_application' => ($_date < time-86400) );
%  }
%  if ( $link eq 'popup' ) {
%    
<% header(emt('Payment entered')) %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
    </SCRIPT>

    </BODY></HTML>
%
%  } elsif ( $link eq 'custnum' ) {
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?$linknum") %>
%  } else {
%    die "unknown link $link";
%  }
%
%}
<%init>

my $conf = FS::Conf->new;

$cgi->param('linknum') =~ /^(\d+)$/
  or die "Illegal linknum: ". $cgi->param('linknum');
my $linknum = $1;

$cgi->param('link') =~ /^(custnum|invnum|popup)$/
  or die "Illegal link: ". $cgi->param('link');
my $field = my $link = $1;
$field = 'custnum' if $field eq 'popup';

my $_date = parse_datetime($cgi->param('_date'));

my $new = new FS::cust_pay ( {
  $field => $linknum,
  _date  => $_date,
  map {
    $_, scalar($cgi->param($_));
  } qw( paid payby payinfo paybatch
        pkgnum discount_term
        bank depositor account teller
      )
  #} fields('cust_pay')
} );

my @rights = ('Post payment');
push @rights, 'Post check payment' if $new->payby eq 'BILL';
push @rights, 'Post cash payment'  if $new->payby eq 'CASH';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right(\@rights);

my $error ||= $new->insert( 'manual' => 1 );

</%init>
