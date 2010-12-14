<% header("Location disabled") %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
</BODY>
</HTML>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
my $error;

die "access denied"
  unless $curuser->access_right('Change customer package');

my $locationnum = $cgi->param('locationnum');
my $cust_location = qsearchs({
  'select'    => 'cust_location.*',
  'table'     => 'cust_location',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'locationnum' => $locationnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "unknown locationnum $locationnum" unless $cust_location;

my @pkgs = qsearch('cust_pkg', { 'locationnum' => $locationnum,
                                 'cancel'      => '' });
if ( @pkgs ) {
  $error = "Location $locationnum has active packages"
}
else {
  $cust_location->disabled('Y');
  $error = $cust_location->replace;
}
die $error if $error;
</%init>
