<% $server->process %>

<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

# false laziness with view/elements/svc_Common.html
# only doing this to check agent access, don't actually use $svc_x
my %param = $cgi->param('arg');
my $svcnum = $param{'svcnum'};
my $svc_x = qsearchs({
  'select'    => 'svc_broadband.*',
  'table'     => 'svc_broadband',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
}) or die "Unknown svcnum $svcnum in svc_broadband table\n";

my $server = FS::UI::Web::JSRPC->new('FS::part_export::cacti::process_graphs', $cgi);
</%init>

