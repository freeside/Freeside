<% include('/elements/header-popup.html', "Edit Location") %>

<% include('/elements/error.html') %>

<FORM NAME="EditLocationForm" 
ACTION="<% $p %>edit/process/cust_location.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="locationnum" VALUE="<% $locationnum %>">

<% ntable('#cccccc') %>
<% include('/elements/location.html',
            'object'        => $cust_location,
            'no_asterisks'  => 1,
            ) %>
</TABLE>

<BR>
<SCRIPT TYPE="text/javascript">
function areyousure() {
  return confirm('Modify this service location?');
}
</SCRIPT>
<INPUT TYPE="submit" VALUE="Submit" onclick="return areyousure()">

</FORM>
</BODY>
</HTML>

<%init>

my $conf = new FS::Conf;

my $curuser = $FS::CurrentUser::CurrentUser;

# it's the same access right you'd need to do this by editing packages
die "access denied"
  unless $curuser->access_right('Change customer package');

my $locationnum = scalar($cgi->param('locationnum'));
my $cust_location = qsearchs({
    'select'    => 'cust_location.*',
    'table'     => 'cust_location',
    'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
    'hashref'   => { 'locationnum' => $locationnum },
    'extra_sql' => ' AND '. $curuser->agentnums_sql,
  }) or die "unknown locationnum $locationnum";

die "can't edit disabled locationnum $locationnum" if $cust_location->disabled;

my $cust_main = qsearchs('cust_main', { 'custnum' => $cust_location->custnum })
  or die "can't get cust_main record for custnum ". $cust_location->custnum;

my @cust_pkgs = qsearch('cust_pkg', { 'locationnum' => $locationnum });

</%init>
