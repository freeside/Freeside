<& /elements/header-popup.html, mt("Customer suspended") &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
<%init>

#false laziness w/cust_main-cancel.cgi

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Suspend customer');

my $custnum;
my $adjourn = '';
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $custnum = $1;
  $adjourn = $cgi->param('adjourn');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ || die "Illegal custnum";
  $custnum = $1;
}

#untaint reasonnum / create new reason
my ($reasonnum, $error) = $m->comp('process/elements/reason');
if (!$reasonnum) {
  $error ||= 'Reason required';
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
} );

if ( $error ) {
  # do nothing
} elsif ( $cgi->param('now_or_later') ) {
  $adjourn = parse_datetime($adjourn);
  if($adjourn) {
    #warn "setting adjourn dates on custnum#$custnum\n";
    my @pkgs = $cust_main->unsuspended_pkgs;
    my @errors = grep {$_} map { $_->suspend(
      'reason'  => $reasonnum,
      'date'    => $adjourn,
    ) } @pkgs;
    $error = join(' / ', @errors);
  } else {
    $error = ("error parsing adjourn date: ".$cgi->param('adjourn'));
  }
} else {
  warn "suspending $cust_main";
  $error = $cust_main->suspend(
    'reason' => $reasonnum,
  );
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "suspend_cust.html?". $cgi->query_string );
}

</%init>
