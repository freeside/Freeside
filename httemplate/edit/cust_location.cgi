<% include('/elements/header-popup.html', "Edit Location") %>

<% include('/elements/error.html') %>

<FORM NAME="EditLocationForm" 
ACTION="<% $p %>edit/process/cust_location.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="locationnum" VALUE="<% $locationnum %>">

<% ntable('#cccccc') %>
<& /elements/location.html,
  'object'              => $cust_location,
  'no_asterisks'        => 1,
  # these are service locations, so they need all this stuff
  'enable_coords'       => 1,
  'enable_district'     => 1,
  'enable_censustract'  => 1,
&>
<& /elements/standardize_locations.html,
            'form'          => 'EditLocationForm',
            'callback'      => 'document.EditLocationForm.submit();',
            'with_census'   => 1,
            'with_census_functions' => 1,
&>
</TABLE>

<BR>
<SCRIPT TYPE="text/javascript">
function go() {
  confirm('Modify this service location?') &&
    standardize_locations();
}

function submit_abort() {
  nd(1);
}
</SCRIPT>
<INPUT TYPE="button" NAME="submitButton" VALUE="Submit" onclick="go()">
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
