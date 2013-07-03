<& elements/search.html,
  'title'       => $title,
  'name'        => 'package types',
  'query'       => $query,
  'count_query' => $count_query,
  'header'      => \@head,
  'fields'      => \@fields,
  'links'       => \@links,
  'align'       => 'clrrrrr',
  'footer_data' => $totals,
&>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Summarize packages');

my $title = 'Package Summary Report';
my ($begin, $end) = FS::UI::Web::parse_beginning_ending($cgi);
if($begin > 0) {
  $title = "$title (".
    $cgi->param('beginning').' - '.$cgi->param('ending').')';
}

my $agentnums_sql = $curuser->agentnums_sql(
                      'null'       => 1,
                      'table'      => 'main',
                    );

my $extra_sql = " freq != '0' AND $agentnums_sql";

#tiny bit of false laziness w/cust_pkg.pm::search
if ( grep { $_ eq 'classnum' } $cgi->param ) {
  if ( $cgi->param('classnum') eq '' ) {
    $extra_sql .= ' AND main.classnum IS NULL';
  } elsif ( $cgi->param('classnum') =~ /^(\d+)$/ && $1 ne '0' ) {
    $extra_sql .= " AND main.classnum = $1 ";
  }
}

my $active_sql = 'setup IS NOT NULL AND susp IS NULL AND cancel IS NULL';
my $suspended_sql = 'setup IS NOT NULL AND susp IS NOT NULL AND cancel IS NULL';
my $active_or_suspended_sql = 'setup IS NOT NULL AND cancel IS NULL';
my %conds;

$conds{'before'} = { 'date' => $begin, 'status' => 'active,suspended' };
$conds{'after'}  = { 'date' => $end,   'status' => 'active,suspended' };
$conds{'active'} = { 'date' => $end,   'status' => 'active' };
$conds{'suspended'} = { 'date' => $end, 'status' => 'suspended' };

my @select;
my $totals = FS::part_pkg->new({pkg => 'Total'});
foreach my $column (keys %conds) {
  my $h_search = FS::h_cust_pkg->search($conds{$column});
  my $count_query = $h_search->{count_query};

  # push a select expression for the total packages with pkgpart=main.pkgpart
  push @select, "($count_query AND h_cust_pkg.pkgpart = main.pkgpart) AS $column";

  # and query the total packages with pkgpart=any of the main.pkgparts
  my $total = FS::Record->scalar_sql($count_query . 
    " AND h_cust_pkg.pkgpart IN(SELECT pkgpart FROM part_pkg AS main WHERE $extra_sql)"
  );
  $totals->set($column => $total);
}

my $query = {
  'table'       => 'part_pkg',
  'addl_from'   => 'AS main',
  'select'      => join(', ', 'main.*', @select),
  'extra_sql'   => "WHERE $extra_sql",
};

my $count_query = "SELECT COUNT(*) FROM part_pkg AS main WHERE $extra_sql";

my $baselink = "h_cust_pkg.html?";
if ( $cgi->param('classnum') =~ /^\d*$/ ) {
  $baselink .= "classnum=".$cgi->param('classnum').';';
}
my @links = ( #arguments to h_cust_pkg.html, except for pkgpart
  '',
  '',
  [ $baselink . "status=active,suspended;date=$begin;pkgpart=", 'pkgpart' ],
  '',
  [ $baselink . "status=active,suspended;date=$end;pkgpart=", 'pkgpart' ],
  [ $baselink . "status=active;date=$end;pkgpart=", 'pkgpart' ],
  [ $baselink . "status=suspended;date=$end;pkgpart=", 'pkgpart' ],
);

my @head = ('#',
            'Package',
            'Before Period',
            'Sales',
            'Total',
            'Active',
            'Suspended');

my @fields = (
  'pkgpart',
  'pkg',
  'before',
  sub { $_[0]->after - $_[0]->before },
  'after',
  'active',
  'suspended',
  );

if ( !$begin ) {
  # remove the irrelevant 'before' column
  splice(@$_,2,1) foreach \@head, \@fields, \@links;
}

</%init>
