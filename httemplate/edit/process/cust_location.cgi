% if ($error) {
%   $cgi->param('error', Dumper($error));
%   $cgi->redirect(popurl(3). 'edit/cust_location.cgi?'. $cgi->query_string );
% } else {

    <% header("Location changed") %>
      <SCRIPT TYPE="text/javascript">
        window.top.location.reload();
      </SCRIPT>
    </BODY>
    </HTML>

% }
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

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

my $new = FS::cust_location->new({
  custnum     => $cust_location->custnum,
  prospectnum => $cust_location->prospectnum,
  map { $_ => scalar($cgi->param($_)) }
    qw( address1 address2 city county state zip country )
});

my $error = $cust_location->move_to($new);

</%init>
