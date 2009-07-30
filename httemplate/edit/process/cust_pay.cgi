%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_pay.cgi?'. $cgi->query_string ) %>
%} elsif ( $field eq 'invnum' ) {
<% $cgi->redirect(popurl(3). "view/cust_bill.cgi?$linknum") %>
%} elsif ( $field eq 'custnum' ) {
%  if ( $cgi->param('apply') eq 'yes' ) {
%    my $cust_main = qsearchs('cust_main', { 'custnum' => $linknum })
%      or die "unknown custnum $linknum";
%    $cust_main->apply_payments;
%  }
%  if ( $link eq 'popup' ) {
%    
<% header('Payment entered') %>
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

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Post payment');

$cgi->param('linknum') =~ /^(\d+)$/
  or die "Illegal linknum: ". $cgi->param('linknum');
my $linknum = $1;

$cgi->param('link') =~ /^(custnum|invnum|popup)$/
  or die "Illegal link: ". $cgi->param('link');
my $field = my $link = $1;
$field = 'custnum' if $field eq 'popup';

my $_date = str2time($cgi->param('_date'));

my $new = new FS::cust_pay ( {
  $field => $linknum,
  _date  => $_date,
  map {
    $_, scalar($cgi->param($_));
  } qw( paid payby payinfo paybatch
        pkgnum
      )
  #} fields('cust_pay')
} );

my $error = $new->insert( 'manual' => 1 );

</%init>
