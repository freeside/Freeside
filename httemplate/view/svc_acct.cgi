<!-- $Id: svc_acct.cgi,v 1.10 2002-01-30 14:18:09 ivan Exp $ -->
<%

my $conf = new FS::Conf;
my $mydomain = $conf->config('domain');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_acct;

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc' , { 'svcnum' => $svcnum } );
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

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $domain;
if ( $svc_acct->domsvc ) {
  my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc } );
  die "Unknown domain" unless $svc_domain;
  $domain = $svc_domain->domain;
} else {
  unless ( $mydomain ) {
    die "No legacy domain config file and no svc_domain.svcnum record ".
        "for svc_acct.domsvc: ". $cust_svc->domsvc;
  }
  $domain = $mydomain;
}

print header('Account View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
));

#print qq!<BR><A HREF="../misc/sendconfig.cgi?$svcnum">Send account information</A>!;

print qq!<A HREF="${p}edit/svc_acct.cgi?$svcnum">Edit this information</A><BR>!.
      &ntable("#cccccc"). '<TR><TD>'. &ntable("#cccccc",2).
      "<TR><TD ALIGN=\"right\">Service number</TD>".
        "<TD BGCOLOR=\"#ffffff\">$svcnum</TD></TR>".
      "<TR><TD ALIGN=\"right\">Service</TD>".
        "<TD BGCOLOR=\"#ffffff\">". $part_svc->svc. "</TD></TR>".
      "<TR><TD ALIGN=\"right\">Username</TD>".
        "<TD BGCOLOR=\"#ffffff\">". $svc_acct->username. "</TD></TR>"
;

print "<TR><TD ALIGN=\"right\">Domain</TD>".
        "<TD BGCOLOR=\"#ffffff\">". $domain, "</TD></TR>";

print "<TR><TD ALIGN=\"right\">Password</TD><TD BGCOLOR=\"#ffffff\">";
my $password = $svc_acct->_password;
if ( $password =~ /^\*\w+\* (.*)$/ ) {
  $password = $1;
  print "<I>(login disabled)</I> ";
}
if ( $conf->exists('showpasswords') ) {
  print "$password";
} else {
  print "<I>(hidden)</I>";
}
print "</TR></TD>";
$password = '';

my $svc_acct_pop = qsearchs('svc_acct_pop',{'popnum'=>$svc_acct->popnum});
print "<TR><TD ALIGN=\"right\">Access number</TD>".
      "<TD BGCOLOR=\"#ffffff\">". $svc_acct_pop->text. '</TD></TR>'
  if $svc_acct_pop;

if ($svc_acct->uid ne '') {
  print "<TR><TD ALIGN=\"right\">Uid</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->uid. "</TD></TR>",
        "<TR><TD ALIGN=\"right\">Gid</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->gid. "</TD></TR>",
        "<TR><TD ALIGN=\"right\">GECOS</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->finger. "</TD></TR>",
        "<TR><TD ALIGN=\"right\">Home directory</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->dir. "</TD></TR>",
        "<TR><TD ALIGN=\"right\">Shell</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->shell. "</TD></TR>",
        "<TR><TD ALIGN=\"right\">Quota</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->quota. "</TD></TR>"
  ;
} else {
  print "<TR><TH COLSPAN=2>(No shell account)</TH></TR>";
}

if ($svc_acct->slipip) {
  print "<TR><TD ALIGN=\"right\">IP address</TD><TD BGCOLOR=\"#ffffff\">".
        ( ( $svc_acct->slipip eq "0.0.0.0" || $svc_acct->slipip eq '0e0' )
          ? "<I>(Dynamic)</I>"
          : $svc_acct->slipip
        ). "</TD>";
  my($attribute);
  foreach $attribute ( grep /^radius_/, fields('svc_acct') ) {
    #warn $attribute;
    $attribute =~ /^radius_(.*)$/;
    my $pattribute = $FS::raddb::attrib{$1};
    print "<TR><TD ALIGN=\"right\">Radius (reply) $pattribute</TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->getfield($attribute).
          "</TD></TR>";
  }
  foreach $attribute ( grep /^rc_/, fields('svc_acct') ) {
    #warn $attribute;
    $attribute =~ /^rc_(.*)$/;
    my $pattribute = $FS::raddb::attrib{$1};
    print "<TR><TD ALIGN=\"right\">Radius (check) $pattribute: </TD>".
          "<TD BGCOLOR=\"#ffffff\">". $svc_acct->getfield($attribute).
          "</TD></TR>";
  }
} else {
  print "<TR><TH COLSPAN=2>(No SLIP/PPP account)</TH></TR>";
}

print "</TABLE></TD></TR></TABLE></BODY></HTML>";

%>
