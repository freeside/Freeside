<% include("/elements/header.html", "Website View", menubar(
    ( ( $custnum )
      ? ( "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
        )                                                                       
      : ( "Cancel this (unaudited) website" =>
            "${p}misc/cancel-unaudited.cgi?$svcnum" )
    ),
  ))
%>

<A HREF="<% $p %>edit/svc_www.cgi?<% $svcnum %>">Edit this information</A><BR>

<% ntable("#cccccc", 2) %>

  <TR>
    <TD ALIGN="right">Service number</TD>
    <TD BGCOLOR="#ffffff"><% $svcnum %></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Website name</TD>
    <TD BGCOLOR="#ffffff"><A HREF="http://<% $www %>"><% $www %></A></TD>
  </TR>

% if (  $part_svc->part_svc_column('usersvc')->columnflag ne 'F'
%       || $part_svc->part_svc_column('usersvc')->columnvalue !~ /^\s*$/) {

    <TR>
      <TD ALIGN="right">Account</TD>
      <TD BGCOLOR="#ffffff">
%       if ( $usersvc ) {
          <A HREF="<% $p %>view/svc_acct.cgi?<% $usersvc %>"><% $email %></A>
%       } else {
          </i>(none)</i>
%       }
      </TD>
    </TR>

% }

  <TR>
    <TD ALIGN="right">Config lines</TD>
    <TD BGCOLOR="#ffffff"><PRE><% join("\n", $svc_www->config) |h %>"</PRE></TD>
  </TR>

% foreach (sort { $a cmp $b } $svc_www->virtual_fields) {
    <% $svc_www->pvf($_)->widget('HTML', 'view', $svc_www->getfield($_)) %>
% }

</TABLE>

<BR>
<% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
 unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_www = qsearchs({
  'select'    => 'svc_www.*',
  'table'     => 'svc_www',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
}) or die "svc_www: Unknown svcnum $svcnum";

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

my $part_svc=qsearchs('part_svc',{'svcpart'=>$cust_svc->svcpart})
  or die "svc_www: Unknown svcpart" . $cust_svc->svcpart;

my $usersvc = $svc_www->usersvc;
my $svc_acct = '';
my $email = '';
if ( $usersvc ) {
  $svc_acct = qsearchs('svc_acct', { 'svcnum' => $usersvc } )
    or die "svc_www: Unknown usersvc $usersvc";
  $email = $svc_acct->email;
}

my $domain_record = qsearchs('domain_record', { 'recnum' => $svc_www->recnum } )
  or die "svc_www: Unknown recnum ". $svc_www->recnum;

my $www = $domain_record->zone;

</%init>
