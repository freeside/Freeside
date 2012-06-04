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

my @errors;
if($cgi->param('now_or_later')) {
  $adjourn = parse_datetime($adjourn);
  if($adjourn) {
    #warn "setting adjourn dates on custnum#$custnum\n";
    my @pkgs = $cust_main->unsuspended_pkgs;
    @errors = grep {$_} map { $_->suspend(
      'reason'  => $reasonnum,
      'date'    => $adjourn,
    ) } @pkgs;
  }
  else {
    @errors = ("error parsing adjourn date: ".$cgi->param('adjourn'));
  }
}
else {
  warn "suspending $cust_main";
  @errors = $cust_main->suspend(
    'reason' => $reasonnum,
  );
}
my $error = join(' / ', @errors) if scalar(@errors);

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "suspend_cust.html?". $cgi->query_string );
}

</%init>
