<!-- $Id: link.cgi,v 1.3 2002-01-30 14:18:09 ivan Exp $ -->
<%

$cgi->param('pkgnum') =~ /^(\d+)$/;
my $pkgnum = $1;
$cgi->param('svcpart') =~ /^(\d+)$/;
my $svcpart = $1;
$cgi->param('svcnum') =~ /^(\d*)$/;
my $svcnum = $1;

unless ( $svcnum ) {
  my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my($svcdb) = $part_svc->getfield('svcdb');
  $cgi->param('link_field') =~ /^(\w+)$/; my($link_field)=$1;
  my($svc_acct)=qsearchs($svcdb,{$link_field => $cgi->param('link_value') });
  eidiot("$link_field not found!") unless $svc_acct;
  $svcnum=$svc_acct->svcnum;
}

my $old = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "svcnum not found!" unless $old;
my $new = new FS::cust_svc ({
  'svcnum' => $svcnum,
  'pkgnum' => $pkgnum,
  'svcpart' => $svcpart,
});

my $error = $new->replace($old);

unless ($error) {
  #no errors, so let's view this customer.
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?$pkgnum");
} else {
  idiot($error);
}

%>
