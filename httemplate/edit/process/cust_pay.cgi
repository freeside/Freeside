<%

$cgi->param('linknum') =~ /^(\d+)$/
  or die "Illegal linknum: ". $cgi->param('linknum');
my $linknum = $1;

$cgi->param('link') =~ /^(custnum|invnum)$/
  or die "Illegal link: ". $cgi->param('link');
my $link = $1;

my $new = new FS::cust_pay ( {
  $link => $linknum,
  map {
    $_, scalar($cgi->param($_));
  } qw(paid _date payby payinfo paybatch)
  #} fields('cust_pay')
} );

my $error = $new->insert;

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). 'cust_pay.cgi?'. $cgi->query_string );
} elsif ( $link eq 'invnum' ) {
  print $cgi->redirect(popurl(3). "view/cust_bill.cgi?$linknum");
} elsif ( $link eq 'custnum' ) {
  if ( $cgi->param('apply') eq 'yes' ) {
    my $cust_main = qsearchs('cust_main', { 'custnum' => $linknum })
      or die "unknown custnum $linknum";
    $cust_main->apply_payments;
  }
  if ( $cgi->param('quickpay') eq 'yes' ) {
    print $cgi->redirect(popurl(3). "search/cust_main-quickpay.html");
  } else {
    print $cgi->redirect(popurl(3). "view/cust_main.cgi?$linknum");
  }
}

%>
