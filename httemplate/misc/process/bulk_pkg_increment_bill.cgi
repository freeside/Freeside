%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'bulk_pkg_increment_bill.cgi?'. $cgi->query_string ) %>
%} else {
<% header('Packages Adjusted') %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
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

for my $param (qw(agentnum magic status classnum pkgpart)) {
  $search_hash{$param} = $cgi->param($param)
    if $cgi->param($param);
}

###
# parse dates
###

#false laziness w/report_cust_pkg.html
# and, now, w/bulk_change_pkg.cgi
my %disable = (
  'all'             => {},
  'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'adjourn'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, },
  'active'          => { 'susp'=>1, 'cancel'=>1 },
  'suspended'       => { 'cancel' => 1 },
  'cancelled'       => {},
  ''                => {},
);

foreach my $field (qw( setup last_bill bill adjourn susp expire cancel )) {

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
