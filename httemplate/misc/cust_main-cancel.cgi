<% header("Customer cancelled") %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
<%init>

my $custnum;
my $ban = '';
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $custnum = $1;
  $ban = $cgi->param('ban');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ || die "Illegal custnum";
  $custnum = $1;
}

#false laziness w/process/cancel_pkg.html

#untaint reasonnum
my $reasonnum = $cgi->param('reasonnum');
$reasonnum =~ /^(-?\d+)$/ || die "Illegal reasonnum";
$reasonnum = $1;

if ($reasonnum == -1) {
  $reasonnum = {
    'typenum' => scalar( $cgi->param('newreasonnumT') ),
    'reason'  => scalar( $cgi->param('newreasonnum' ) ),
  };
}

#eslaf

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
} );

warn "cancelling $cust_main";
my @errors = $cust_main->cancel(
  'ban'    => $ban,
  'reason' => $reasonnum,
);
my $error = join(' / ', @errors) if scalar(@errors);

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "cancel_cust.html?". $cgi->query_string );
}

</%init>
