<!-- mason kludge -->
<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_broadband = qsearchs( 'svc_broadband', { 'svcnum' => $svcnum } )
  or die "svc_broadband: Unknown svcnum $svcnum";

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

my $router = $svc_broadband->addr_block->router;

if (not $router) { die "Could not lookup router for svc_broadband (svcnum $svcnum)" };

my (
     $routername,
     $routernum,
     $speed_down,
     $speed_up,
     $ip_addr
   ) = (
     $router->getfield('routername'),
     $router->getfield('routernum'),
     $svc_broadband->getfield('speed_down'),
     $svc_broadband->getfield('speed_up'),
     $svc_broadband->getfield('ip_addr')
   );



print header('Broadband Service View', menubar(
  ( ( $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) website" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)).
      qq!<A HREF="${p}edit/svc_broadband.cgi?$svcnum">Edit this information</A><BR>!.
      ntable("#cccccc"). '<TR><TD>'. ntable("#cccccc",2).
      qq!<TR><TD ALIGN="right">Service number</TD>!.
        qq!<TD BGCOLOR="#ffffff">$svcnum</TD></TR>!.
      qq!<TR><TD ALIGN="right">Router</TD>!.
        qq!<TD BGCOLOR="#ffffff">$routernum: $routername</TD></TR>!.
      qq!<TR><TD ALIGN="right">Download Speed</TD>!.
        qq!<TD BGCOLOR="#ffffff">$speed_down</TD></TR>!.
      qq!<TR><TD ALIGN="right">Upload Speed</TD>!.
        qq!<TD BGCOLOR="#ffffff">$speed_up</TD></TR>!.
      qq!<TR><TD ALIGN="right">IP Address</TD>!.
        qq!<TD BGCOLOR="#ffffff">$ip_addr</TD></TR>!.
      '</TD></TR><TR ROWSPAN="1"><TD></TD></TR>';

foreach (sort { $a cmp $b } $svc_broadband->virtual_fields) {
  print $svc_broadband->pvf($_)->widget('HTML', 'view', 
      $svc_broadband->getfield($_)), "\n";
}

print '</TABLE>';

print '<BR>'. joblisting({'svcnum'=>$svcnum}, 1).
      '</BODY></HTML>'
;
%>
