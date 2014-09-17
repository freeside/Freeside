<& /elements/header-popup.html, mt("Customer unsuspended") &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
<%init>

#false laziness w/cust_main-cancel.cgi

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unsuspend customer');

my $custnum;
my $resume = '';
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $custnum = $1;
  $resume = $cgi->param('resume');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ || die "Illegal custnum";
  $custnum = $1;
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
} );

my @errors;
if($cgi->param('now_or_later')) {
  $resume = parse_datetime($resume);
  if($resume) {
    #warn "setting resume dates on custnum#$custnum\n";
    my @pkgs = $cust_main->suspended_pkgs;
    if (!$cgi->param('release_hold')) {
      # then avoid packages that are on hold
      @pkgs = grep { $_->get('setup') } @pkgs;
    }
    @errors = grep {$_} map { $_->unsuspend(
      'date'    => $resume,
    ) } @pkgs;
  }
  else {
    @errors = ("error parsing adjourn date: ".$cgi->param('adjourn'));
  }
}
else { # unsuspending now
  warn "unsuspending $cust_main";
  @errors = $cust_main->unsuspend;

  if ( $cgi->param('release_hold') ) {
    push @errors, $cust_main->release_hold;
  }
}
my $error = join(' / ', @errors) if scalar(@errors);

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "unsuspend_cust.html?". $cgi->query_string );
}

</%init>
