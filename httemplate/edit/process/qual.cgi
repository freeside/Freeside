%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(3). 'misc/qual.html?'. $cgi->query_string ) %>
%} else {
<% header('Qualification entered') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location = '<% popurl(3).'view/qual.cgi?qualnum='. $qual->qualnum %>';
  </SCRIPT>
  </BODY></HTML>
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Qualify service');

# copied from misc/qual.html :(
$cgi->param('custnum') =~ /^(\d+)$/;
my $custnum = $1;
$cgi->param('prospectnum') =~ /^(\d+)$/;
my $prospectnum = $1;
my $cust_or_prospect = $custnum ? "cust" : "prospect";
my $table = $cust_or_prospect . "_main";
my $custnum_or_prospectnum = $custnum ? $custnum : $prospectnum;
my $cust_main_or_prospect_main = qsearchs({
  'table'     => $table,
  'hashref'   => { $cust_or_prospect."num" => $custnum_or_prospectnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "neither prospect nor customer specified or found" 
    unless $cust_main_or_prospect_main;

$cgi->param('exportnum') =~ /^(\d+)$/ or die 'illegal exportnum';
my $exportnum = $1;

my $phonenum = $cgi->param('phonenum');
$phonenum =~ s/\D//g;
$phonenum =~ /^(\d*)$/ or die 'illegal phonenum';
my $phonenum = $1;

$cgi->param('locationnum') =~ /^(\-?\d*)$/
  or die 'illegal locationnum '. $cgi->param('locationnum');
my $locationnum = $1;

my $error = '';
my $cust_location = '';
if ( $locationnum == -1 ) { # adding a new one

  $cust_location = new FS::cust_location {
    $cust_or_prospect."num" => $custnum_or_prospectnum,
    map { $_ => scalar($cgi->param($_)) }
      qw( address1 address2 city county state zip country geocode ),
      grep scalar($cgi->param($_)),
        qw( location_type location_number location_kind )
  };

          #locationnum '': default service location
} elsif ( $locationnum eq '' && $cust_or_prospect eq 'prospect' ) {
    die "a location must be specified explicitly for prospects";

          #locationnum -2: address not required for qual
} elsif ( $locationnum == -2 && $phonenum eq '' ) {
  $error = "Nothing to qualify - neither phone number nor address specified";
}

my $qual = new FS::qual {
  'status' => 'N',
};
$qual->phonenum($phonenum) if $phonenum ne '';
$qual->set( $cust_or_prospect."num" => $custnum_or_prospectnum )
  unless $locationnum == -1 || $locationnum > 0;
$qual->exportnum($exportnum) if $exportnum > 0;

$error ||= $qual->insert( 'cust_location' => $cust_location );

</%init>
