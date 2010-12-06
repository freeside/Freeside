<% include("/elements/header.html","View Qualification") %>

% if ( $cust_or_prospect->custnum ) {

  <% include( '/elements/small_custview.html', $cust_or_prospect->custnum, '', 1,
     "${p}view/cust_main.cgi") %>
  <BR>

% }

<B>Qualification #<% $qual->qualnum %></B>
<% ntable("#cccccc", 2) %>
<% include('elements/tr.html', label => 'Status', value => $qual->status_long ) %>
<% include('elements/tr.html', label => 'Service Telephone Number', value => $qual->phonenum ) %>
<% include('elements/tr.html', label => 'Address', value => $location_line ) %>
% if ( $location_kind ) {
<% include('elements/tr.html', label => 'Location Kind', value => $location_kind ) %>
% } if ( $export ) { 
<% include('elements/tr.html', label => 'Qualified using', value => $export->exportname ) %>
<% include('elements/tr.html', label => 'Vendor Qualification #', value => $qual->vendor_qual_id ) %>
% } 
</TABLE>
<BR><BR>

% if ( $export ) {
<% $export->qual_html($qual) %>
% }

<%init>

# XXX: add access right for quals?

my $qualnum;
if ( $cgi->param('qualnum') ) {
  $cgi->param('qualnum') =~ /^(\d+)$/ or die "unparsable qualnum";
  $qualnum = $1;
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "no qualnum";
  $qualnum = $1;
}

my $qual = qsearchs('qual', { qualnum => $qualnum }) or die "invalid qualnum";
my $location_line = '';
my %location_hash = $qual->location;
my $cust_location;
if ( %location_hash ) {
    $cust_location = new FS::cust_location(\%location_hash);
    $location_line = $cust_location->location_label;
}
# XXX: geocode_Mixin location_label doesn't currently have the new cust_location fields - add them

my $location_kind;
$location_kind = "Residential" if $cust_location->location_kind eq 'R';
$location_kind = "Business" if $cust_location->location_kind eq 'B';

my $cust_or_prospect = $qual->cust_or_prospect;

my $export;
if ( $qual->exportnum ) {
    $export = qsearchs('part_export', { exportnum => $qual->exportnum } )
		or die 'invalid exportnum';
}

</%init>
