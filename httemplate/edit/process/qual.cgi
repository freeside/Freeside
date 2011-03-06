%if ($error) {
%  $cgi->param('error', $error);
%  $dbh->rollback if $oldAutoCommit;
<% $cgi->redirect(popurl(3). 'misc/qual.html?'. $cgi->query_string ) %>
%} else {
%  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
<% header('Qualification entered') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location = '<% popurl(3). "view/qual.cgi?qualnum=$qualnum" %>';
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

my $oldAutoCommit = $FS::UID::AutoCommit;
local $FS::UID::AutoCommit = 0;
my $dbh = dbh;
my $error = '';
my $cust_location;
if ( $locationnum == -1 ) { # adding a new one
  my %location_hash = map { $_ => scalar($cgi->param($_)) }
	qw( address1 address2 city county state zip country geocode );
  $location_hash{$cust_or_prospect."num"} = $custnum_or_prospectnum;
  $location_hash{location_type} = $cgi->param('location_type') 
    if $cgi->param('location_type');
  $location_hash{location_number} = $cgi->param('location_number') 
    if $cgi->param('location_number');
  $location_hash{location_kind} = $cgi->param('location_kind') 
    if $cgi->param('location_kind');
  $cust_location = new FS::cust_location ( { %location_hash } );
  $error = $cust_location->insert;
  die "Unable to insert cust_location: $error" if $error;
}
elsif ( $locationnum eq '' ) { # default service location
    if ( $custnum ) { 
	  $cust_location = new FS::cust_location ( {
		$cust_main_or_prospect_main->location_hash,
		custnum => $custnum,
	  } );
    } elsif ( $prospectnum ) {
	die "a location must be specified explicitly for prospects";
    }
}
elsif ( $locationnum != -2 ) { # -2 = address not required for qual
  $cust_location = qsearchs('cust_location', { 'locationnum' => $locationnum })
    or die 'Invalid locationnum'; 
}

my $export;
if ( $exportnum > 0 ) {
 $export = qsearchs( 'part_export', { 'exportnum' => $exportnum } )
    or die 'Invalid exportnum';
}

die "Nothing to qualify - neither TN nor address specified" 
    unless ( defined $cust_location || $phonenum ne '' );

my $qual;
if ( $locationnum != -2 && $cust_location->locationnum > 0 ) {
    $qual = new FS::qual( { locationnum => $cust_location->locationnum } );
}
else { # a cust_main default service address *OR* address not required
    $qual = new FS::qual( { $cust_or_prospect."num" => $custnum_or_prospectnum } );
}
$qual->phonenum($phonenum) if $phonenum ne '';
$qual->status('N');

if ( $export ) {
    $qual->exportnum($export->exportnum);
    my $qres = $export->qual($qual);
    $error = "Qualification error: $qres" unless ref($qres);
    unless ( $error ) {
	$qual->status($qres->{'status'}) if $qres->{'status'};
	$qual->vendor_qual_id($qres->{'vendor_qual_id'}) 
	    if $qres->{'vendor_qual_id'};
	$error = $qual->insert($qres->{'options'}) if ref($qres->{'options'});
    }
}

unless ( $error || $qual->qualnum ) {
    $error = $qual->insert;
}

my $qualnum;
unless ( $error ) {
    if($qual->qualnum) {
	$qualnum = $qual->qualnum;
    }
    else {
	$error = "Unable to save qualification";
    }
}

</%init>
