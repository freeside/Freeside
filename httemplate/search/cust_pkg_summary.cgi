<% include('/elements/header.html', $title) %>
<% include('/elements/table-grid.html') %>
  <TR>
% foreach (@head) {
    <TH CLASS="grid" BGCOLOR="#cccccc"><% $_ %></TH>
% }
  </TR>
% my $r=0;
% foreach my $row (@rows) {
  <TR>
%   foreach (@$row) {
    <TD CLASS="grid" ALIGN="right" BGCOLOR="<% $r % 2 ? '#ffffff' : '#eeeeee' %>"><% $_ %></TD>
%   }
  </TR>
%   $r++;
% }
  <TR>
% foreach (@totals) {
    <TD CLASS="grid" ALIGN="right" BGCOLOR="<% $r % 2 ? '#ffffff' : '#eeeeee' %>"><B><% $_ %></B></TD>
% }
  </TR>
</TABLE>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('List packages');

my $title = 'Package Summary Report';
my ($begin, $end) = FS::UI::Web::parse_beginning_ending($cgi);
if($begin > 0) {
  $title = "$title (".
    $cgi->param('beginning').' - '.$cgi->param('ending').')';
}

my @h_sql = FS::h_cust_pkg->sql_h_search($end);

my ($end_sql, $addl_from) = @h_sql[1,3];
$end_sql =~ s/ORDER BY.*//; # breaks aggregate queries

my $begin_sql = $end_sql;
$begin_sql =~ s/$end/$begin/g;

my $active_sql = FS::cust_pkg->active_sql;
my $suspended_sql = FS::cust_pkg->suspended_sql;
my @conds = (
  # SQL WHERE clauses for each column of the table.
  " $begin_sql AND ($active_sql OR $suspended_sql)",
  '',
  " $end_sql AND ($active_sql OR $suspended_sql)",
  " $end_sql AND $active_sql",
  " $end_sql AND $suspended_sql",
  );

$_ =~ s/\bcust_pkg/maintable/g foreach @conds;

my @head = ('Package', 'Before Period', 'Sales', 'Total', 'Active', 'Suspended');
my @rows = ();
my @totals = ('Total', 0, 0, 0, 0, 0);

if( !$begin ) {
  splice @conds, 1, 1;
  splice @head, 1, 1;
}

my $agentnums_sql = $curuser->agentnums_sql(
                      'null'       => 1,
                      'table'      => 'part_pkg',
                    );

my $extra_sql = " WHERE $agentnums_sql";

foreach my $part_pkg (qsearch({ 'table'     => 'part_pkg',
                                'hashref'   => {},
                                'extra_sql' => $extra_sql,
                             })
                     )
{
  my @row = ();
  next if !$part_pkg->freq; # exclude one-time packages
  push @row, $part_pkg->pkg;
  my $i=1;
  foreach my $cond (@conds) {
    if($cond) {
      my $result = qsearchs({ 
                            'table'     => 'h_cust_pkg',
                            'addl_from' => $addl_from.
                                           ' LEFT JOIN cust_main USING ( custnum )',

                            'hashref'   => {},
                            'select'    => 'count(*)',
                            'extra_sql' => 'WHERE pkgpart = '.$part_pkg->pkgpart.$cond.
                                           ' AND '. $curuser->agentnums_sql(
                                                      'table' => 'cust_main',
                                                    ),
                            });
      $row[$i] = $result->getfield('count');
      $totals[$i] += $row[$i];
    }
    $i++;
  }
  $row[2] = $row[3]-$row[1];
  $totals[2] += $row[2];
  push @rows, \@row;
}
</%init>
