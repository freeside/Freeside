<% encode_json( \@return ) %>\
<%init>

# default returned records must maintain consistency with /elements/select-part_pkg.html

my $extra_sql = ' WHERE ' . FS::part_pkg->curuser_pkgs_sql;

# equivalent to agent_virt=1 and agent_null=1 in /elements/select-table.html
$extra_sql .= ' AND ' . 
  $FS::CurrentUser::CurrentUser->agentnums_sql(
    'null' => 1,
  );

my @records = qsearch( {
  'table'     => 'part_pkg',
  'hashref'   => {},
  'extra_sql' => $extra_sql,
  'order_by'  => "ORDER BY pkg",
});

my @return = map { 
  {
    'pkgpart'  => $_->pkgpart,
    'label'    => $_->pkg_comment_only,
    'disabled' => $_->disabled,
  }
} @records;

</%init>
