<% include("/elements/header.html","View Qualification") %>

% if ( $cust_or_prospect->get('custnum') ) {

  <% include( '/elements/small_custview.html', $cust_or_prospect->custnum, '', 1,
     "${p}view/cust_main.cgi") %>

% } elsif ( $cust_or_prospect->get('prospectnum') ) {
%  	my $prospectnum = $cust_or_prospect->get('prospectnum');
% 	my $link = "${p}view/prospect_main.html?$prospectnum";
	<A HREF="<%$link%>">Prospect #<%$prospectnum%></A>
% }

<BR><BR>

<B>Qualification #<% $qual->qualnum %></B>
<% ntable("#cccccc", 2) %>
<% include('elements/tr.html', label => 'Status', value => $qual->status_long ) %>
<% include('elements/tr.html', label => 'Service Telephone Number', value => $qual->phonenum || '(none - dry loop)' ) %>
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
%  my $qual_result = $export->qual_result($qual);
%  if ($qual_result->{'header'}) {
	<B><% $qual_result->{'header'} %></B>
%  }
%  if ($qual_result->{'pkglist'}) { # one of the possible formats
%   my $svcpart = '';
%   my $pkglist = $qual_result->{'pkglist'};
%   my $cust_or_prospect = $qual->cust_or_prospect;
%   my $locationnum = '';
%   my %location = $qual->location_hash;
%   if (%location && $location{'locationnum'}) { 
%      $locationnum = $location{'locationnum'};
%   }
    <UL>
%       foreach my $pkgpart ( keys %$pkglist ) { 
%           my %opt = ( 'label' => $pkglist->{$pkgpart},
%                          'pkgpart' => $pkgpart,
%                          'locationnum' => $locationnum, );
%           if ( $export->exporttype eq 'ikano' ) {
% 		my $pkg_svc = qsearchs('pkg_svc', { 'pkgpart' => $pkgpart,
%                                                 'primary_svc' => 'Y',
%                                               } );
%		$opt{'svcpart'} = $pkg_svc->svcpart if $pkg_svc;
%           }
	    <LI>
%		if($cust_or_prospect && $cust_or_prospect->custnum) {
		   <% include('/view/cust_main/order_pkg_link.html', $qual->cust_or_prospect, %opt) %>
%		}
%		else {
		    <% $opt{label} %>
%		}
	    </LI>
%       }
    </UL>
%  }

%  my $not_avail = $qual_result->{'not_avail'};
%  if ( keys %$not_avail ) {
     <BR>
     Qualifying vendor packages (not yet configured in any package definition):
     <% join(', ', map $not_avail->{$_}, keys %$not_avail ) |h %>
%  }

% }

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Qualify service');

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
my %location_hash = $qual->location_hash;
my $cust_location;
if ( %location_hash ) {
    $cust_location = new FS::cust_location(\%location_hash);
    $location_line = $cust_location->location_label;
}

my $location_kind;
$location_kind = "Residential" if $cust_location->get('location_kind') eq 'R';
$location_kind = "Business" if $cust_location->get('location_kind') eq 'B';

my $cust_or_prospect = $qual->cust_or_prospect;
my $export = $qual->part_export;

</%init>
