<!-- mason kludge -->
<%

my $conf = new FS::Conf;
my $mydomain = $conf->config('domain');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_acct_sm = qsearchs('svc_acct_sm',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_acct_sm;

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

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } )
  or die "Unkonwn svcpart";

print header('Mail Alias View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
));

my($domsvc,$domuid,$domuser) = (
  $svc_acct_sm->domsvc,
  $svc_acct_sm->domuid,
  $svc_acct_sm->domuser,
);
my $svc = $part_svc->svc;
my $svc_domain = qsearchs('svc_domain',{'svcnum'=>$domsvc})
  or die "Corrupted database: no svc_domain.svcnum matching domsvc $domsvc";
my $domain = $svc_domain->domain;
my $svc_acct = qsearchs('svc_acct',{'uid'=>$domuid})
  or die "Corrupted database: no svc_acct.uid matching domuid $domuid";
my $username = $svc_acct->username;

print qq!<A HREF="${p}edit/svc_acct_sm.cgi?$svcnum">Edit this information</A>!,
      "<BR>Service #$svcnum",
      "<BR>Service: <B>$svc</B>",
      qq!<BR>Mail to <B>!, ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser ) , qq!</B>\@<B>$domain</B> forwards to <B>$username</B>\@$mydomain mailbox.!,
      '</BODY></HTML>'
;

%>
