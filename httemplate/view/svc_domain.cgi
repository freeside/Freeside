<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_domain = qsearchs('svc_domain',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_domain;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum);
if ($pkgnum) {
  $cust_pkg=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  $custnum=$cust_pkg->getfield('custnum');
} else {
  $cust_pkg = '';
  $custnum = '';
}

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $email = '';
if ($svc_domain->catchall) {
  my $svc_acct = qsearchs('svc_acct',{'svcnum'=> $svc_domain->catchall } );
  die "Unknown svcpart" unless $svc_acct;
  $email = $svc_acct->email;
}

my $domain = $svc_domain->domain;

print header('Domain View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)),
      "Service #$svcnum",
      "<BR>Service: <B>", $part_svc->svc, "</B>",
      "<BR>Domain name: <B>$domain</B>.",
      qq!<BR>Catch all email <A HREF="${p}misc/catchall.cgi?$svcnum">(change)</A>:!,
      $email ? "<B>$email</B>." : "<I>(none)<I>",
      qq!<BR><BR><A HREF="http://www.geektools.com/cgi-bin/proxy.cgi?query=$domain;targetnic=auto">View whois information.</A>!,
      '</BODY></HTML>',
;
%>
