<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_www = qsearchs( 'svc_www', { 'svcnum' => $svcnum } )
  or die "svc_www: Unknown svcnum $svcnum";

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

my $domain_record = qsearchs('domain_record', { 'recnum' => $svc_www->recnum } )
  or die "svc_www: Unknown recnum". $svc_www->recnum;

my $www = $domain_record->reczone;

print header('Website View', menubar(
  ( ( $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) website" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)),
      "Service #$svcnum",
      "<BR>Website name: <B>$www</B>.",
      '</BODY></HTML>',                
;
%>
