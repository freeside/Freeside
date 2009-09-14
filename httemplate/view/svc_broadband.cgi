<%include("/elements/header.html",'Broadband Service View', menubar(
  ( ( $custnum )
    ? ( "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) website" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  )
))
%>

<% include('/elements/init_overlib.html') %>

<A HREF="<%$p%>edit/svc_broadband.cgi?<%$svcnum%>">Edit this information</A>
<BR>
<%ntable("#cccccc")%>
  <TR>
    <TD>
      <%ntable("#cccccc",2)%>
        <TR>
          <TD ALIGN="right">Service number</TD>
          <TD BGCOLOR="#ffffff"><%$svcnum%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Description</TD>
          <TD BGCOLOR="#ffffff"><%$description%></TD>
        </TR>

%       if ( $router ) {
          <TR>
            <TD ALIGN="right">Router</TD>
            <TD BGCOLOR="#ffffff"><%$router->routernum%>: <%$router->routername%></TD>
          </TR>
%       }

        <TR>
          <TD ALIGN="right">Download Speed</TD>
          <TD BGCOLOR="#ffffff"><%$speed_down%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Upload Speed</TD>
          <TD BGCOLOR="#ffffff"><%$speed_up%></TD>
        </TR>

%       if ( $ip_addr ) { 
          <TR>
            <TD ALIGN="right">IP Address</TD>
            <TD BGCOLOR="#ffffff">
              <%$ip_addr%>
              (<% include('/elements/popup_link-ping.html', 'ip'=>$ip_addr ) %>)
            </TD>
          </TR>
          <TR>
            <TD ALIGN="right">IP Netmask</TD>
            <TD BGCOLOR="#ffffff"><%$addr_block->NetAddr->mask%></TD>
          </TR>
          <TR>
            <TD ALIGN="right">IP Gateway</TD>
            <TD BGCOLOR="#ffffff"><%$addr_block->ip_gateway%></TD>
          </TR>
%       }

        <TR>
          <TD ALIGN="right">MAC Address</TD>
          <TD BGCOLOR="#ffffff"><%$mac_addr%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Latitude</TD>
          <TD BGCOLOR="#ffffff"><%$latitude%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Longitude</TD>
          <TD BGCOLOR="#ffffff"><%$longitude%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Altitude</TD>
          <TD BGCOLOR="#ffffff"><%$altitude%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">VLAN Profile</TD>
          <TD BGCOLOR="#ffffff"><%$vlan_profile%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Authentication Key</TD>
          <TD BGCOLOR="#ffffff"><%$auth_key%></TD>
        </TR>
        <TR COLSPAN="2"><TD></TD></TR>
%
%foreach (sort { $a cmp $b } $svc_broadband->virtual_fields) {
%  print $svc_broadband->pvf($_)->widget('HTML', 'view',
%                                        $svc_broadband->getfield($_)), "\n";
%}
%
%

      </TABLE>
    </TD>
  </TR>
</TABLE>

<BR>
<%ntable("#cccccc", 2)%>
%
%  my $sb_router = qsearchs('router', { svcnum => $svcnum });
%  if ($sb_router) {
%  

  <B>Router associated: <%$sb_router->routername%> </B>
  <A HREF="<%popurl(2)%>edit/router.cgi?<%$sb_router->routernum%>">
    (details)
  </A>
  <BR>
% my @sb_addr_block;
%     if (@sb_addr_block = $sb_router->addr_block) {
%     

  <B>Address space </B>
  <A HREF="<%popurl(2)%>browse/addr_block.cgi">
    (edit)
  </A>
  <BR>
%   print ntable("#cccccc", 1);
%       foreach (@sb_addr_block) { 

    <TR>
      <TD><%$_->ip_gateway%>/<%$_->ip_netmask%></TD>
    </TR>
% } 

  </TABLE>
% } else { 

  <B>No address space allocated.</B>
% } 

  <BR>
%
%  } else {
%


<FORM METHOD="GET" ACTION="<%popurl(2)%>edit/router.cgi">
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%$svcnum%>">
Add router named 
  <INPUT TYPE="text" NAME="routername" SIZE="32" VALUE="Broadband router (<%$svcnum%>)">
  <INPUT TYPE="submit" VALUE="Add router">
</FORM>
%
%}
%


<BR>
<%joblisting({'svcnum'=>$svcnum}, 1)%>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_broadband = qsearchs({
  'select'    => 'svc_broadband.*',
  'table'     => 'svc_broadband',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
}) or die "svc_broadband: Unknown svcnum $svcnum";

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

my $addr_block = $svc_broadband->addr_block;
my $router = $addr_block->router if $addr_block;

#if (not $router) { die "Could not lookup router for svc_broadband (svcnum $svcnum)" };

my (
     $speed_down,
     $speed_up,
     $ip_addr,
     $mac_addr,
     $latitude,
     $longitude,
     $altitude,
     $vlan_profile,
     $auth_key,
     $description,
   ) = (
     $svc_broadband->getfield('speed_down'),
     $svc_broadband->getfield('speed_up'),
     $svc_broadband->getfield('ip_addr'),
     $svc_broadband->mac_addr,
     $svc_broadband->latitude,
     $svc_broadband->longitude,
     $svc_broadband->altitude,
     $svc_broadband->vlan_profile,
     $svc_broadband->auth_key,
     $svc_broadband->description,
   );

</%init>
