%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'bulk_pkg_increment_bill.cgi?'. $cgi->query_string ) %>
%} else {
<& /elements/header-popup.html, 'Packages Adjusted' &>
    <SCRIPT TYPE="text/javascript">
      topreload();
    </SCRIPT>
    </BODY></HTML>
% }
<%init>

local $FS::UID::AutoCommit = 0;
my $dbh = dbh;
my $error;

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages') 
     and $FS::CurrentUser::CurrentUser->access_right('Edit customer package dates');

my $days = $cgi->param('days') or die "missing parameter: days";
$days > 0 or $error = "Number of days must be > 0";

my %search_hash = ();

$search_hash{'query'} = $cgi->param('query');

#scalars
for (qw( agentnum cust_status cust_main_salesnum salesnum custnum magic status
         custom cust_fields pkgbatch zip
         477part 477rownum date 
    )) 
{
  $search_hash{$_} = $cgi->param($_) if length($cgi->param($_));
}

#arrays
for my $param (qw( pkgpart classnum refnum towernum )) {
  $search_hash{$param} = [ $cgi->param($param) ]
    if grep { $_ eq $param } $cgi->param;
}

#scalars that need to be passed if empty
for my $param (qw( censustract censustract2 )) {
  $search_hash{$param} = $cgi->param($param) || ''
    if grep { $_ eq $param } $cgi->param;
}

#location flags (checkboxes)
my @loc = grep /^\w+$/, $cgi->param('loc');
$search_hash{"location_$_"} = 1 foreach @loc;

my $report_option = $cgi->param('report_option');
$search_hash{report_option} = $report_option if $report_option;

for my $param (grep /^report_option_any/, $cgi->param) {
  $search_hash{$param} = $cgi->param($param);
}

###
# parse dates
###

#false laziness w/report_cust_pkg.html and bulk_change_pkg.cgi
my %disable = (
  'all'             => {},
  'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'adjourn'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, },
  'active'          => { 'susp'=>1, 'cancel'=>1 },
  'suspended'       => { 'cancel' => 1 },
  'cancelled'       => {},
  ''                => {},
);

foreach my $field (qw( setup last_bill bill adjourn susp expire contract_end change_date cancel active )) {

  $search_hash{$field.'_null'} = scalar( $cgi->param($field.'_null') );

  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi, $field);

  next if $beginning == 0 && $ending == 4294967295
       or $disable{$cgi->param('status')}->{$field};

  $search_hash{$field} = [ $beginning, $ending ];

}

if(!$error) {
  foreach my $cust_pkg (qsearch(FS::cust_pkg->search(\%search_hash))) {
    next if ! $cust_pkg->bill;
    my $new_cust_pkg = FS::cust_pkg->new({ $cust_pkg->hash });
    $new_cust_pkg->bill($new_cust_pkg->bill + $days*86400);
    $error = $new_cust_pkg->replace($cust_pkg);
    
    if($error) {
      $cgi->param("error",substr($error, 0, 512));
      $dbh->rollback;
      return;
    }
  }

  $dbh->commit;
}

</%init>
