<% include('/elements/header.html', "Customer cancelled") %>
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
  $expire = parse_datetime($expire);
  if($expire) {
    #warn "setting expire dates on custnum#$custnum\n";
    my @pkgs = $cust_main->ncancelled_pkgs;
    @errors = grep {$_} map { $_->cancel(
      'reason'  => $reasonnum,
      'date'    => $expire,
    ) } @pkgs;
  }
  else {
    @errors = ("error parsing expire date: ".$cgi->param('expire'));
  }
}
else {
  warn "cancelling $cust_main";
  @errors = $cust_main->cancel(
    'ban'    => $ban,
    'reason' => $reasonnum,
  );
}
my $error = join(' / ', @errors) if scalar(@errors);

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(1). "cancel_cust.html?". $cgi->query_string );
}

</%init>
