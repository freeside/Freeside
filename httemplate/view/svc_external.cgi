<% include("/elements/header.html",'External Service View', menubar(
  ( ( $custnum )
    ? ( "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) external service" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
)) %>

<A HREF="<%$p%>edit/svc_external.cgi?<%$svcnum%>">Edit this information</A><BR>
<% ntable("#cccccc") %><TR><TD><% ntable("#cccccc",2) %>

<TR><TD ALIGN="right">Service number</TD>
  <TD BGCOLOR="#ffffff"><% $svcnum %></TD></TR>
<TR><TD ALIGN="right"><% FS::Msgcat::_gettext('svc_external-id') || 'External&nbsp;ID' %></TD>
  <TD BGCOLOR="#ffffff"><% $conf->config('svc_external-display_type') eq 'artera_turbo' ? sprintf('%010d', $svc_external->id) : $svc_external->id %></TD></TR>
<TR><TD ALIGN="right"><% FS::Msgcat::_gettext('svc_external-title') || 'Title' %></TD>
  <TD BGCOLOR="#ffffff"><% $svc_external->title %></TD></TR>
% foreach (sort { $a cmp $b } $svc_external->virtual_fields) { 

  <% $svc_external->pvf($_)->widget('HTML', 'view', $svc_external->getfield($_)) %>
% } 


</TABLE></TD></TR></TABLE>
<BR><% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_external = qsearchs({
  'select'    => 'svc_external.*',
  'table'     => 'svc_external',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
}) or die "svc_external: Unknown svcnum $svcnum";

my $conf = new FS::Conf;

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum, $display_custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
  $display_custnum = $cust_pkg->cust_main->display_custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

</%init>
