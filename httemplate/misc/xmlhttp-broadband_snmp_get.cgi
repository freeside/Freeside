<%doc>
Requires arg $svcnum.  Returns JSON-encoded realtime snmp results 
for configured broadband_snmp_get exports.
</%doc>
<% encode_json(\@result) %>\
<%init>

# access/agent permissions lifted from /view/elements/svc_Common.html

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my %arg = $cgi->param('arg');
my $svc = qsearchs({
  'select'    => 'svc_broadband.*',
  'table'     => 'svc_broadband',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => { 'svcnum' => $arg{'svcnum'} },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
}) or die "Unknown svcnum ".$arg{'svcnum'}." in svc_broadband table\n";

my @part_export = $svc->cust_svc->part_svc->part_export('broadband_snmp_get');

my @result;
foreach my $part_export (@part_export) {
  push @result, $part_export->snmp_results($svc);
}

</%init>


