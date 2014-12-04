<& /elements/header-popup.html, mt("Customer cancelled") &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Cancel customer');

my $custnum;
my $ban = '';
my $expire = '';
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $custnum = $1;
  $ban = $cgi->param('ban');
  $expire = $cgi->param('expire');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ || die "Illegal custnum";
  $custnum = $1;
}


#untaint reasonnum / create new reason
my ($reasonnum, $error) = $m->comp('process/elements/reason');
if (!$reasonnum) {
  $error ||= 'Reason required'
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
} );

if ( $error ) {
  # do nothing
} elsif ( $cgi->param('now_or_later') ) {
  $expire = parse_datetime($expire);
  if($expire) {
    #warn "setting expire dates on custnum#$custnum\n";
    my @pkgs = $cust_main->ncancelled_pkgs;
    my @errors = grep {$_} map { $_->cancel(
      'reason'  => $reasonnum,
      'date'    => $expire,
    ) } @pkgs;
    $error = join(' / ', @errors);
  }
  else {
    $error = ("error parsing expire date: ".$cgi->param('expire'));
  }
}
else {
  warn "cancelling $cust_main";
  $error = $cust_main->cancel(
    'ban'    => $ban,
    'reason' => $reasonnum,
  );
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "cancel_cust.html?". $cgi->query_string );
}

</%init>
