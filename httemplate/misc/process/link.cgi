<%

$cgi->param('pkgnum') =~ /^(\d+)$/;
my $pkgnum = $1;
$cgi->param('svcpart') =~ /^(\d+)$/;
my $svcpart = $1;
$cgi->param('svcnum') =~ /^(\d*)$/;
my $svcnum = $1;

unless ( $svcnum ) {
  my $part_svc = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my $svcdb = $part_svc->getfield('svcdb');
  $cgi->param('link_field') =~ /^(\w+)$/;
  my $link_field = $1;
  my $svc_x = ( grep { $_->cust_svc->svcpart == $svcpart } 
                  qsearch( $svcdb, { $link_field => $cgi->param('link_value') })
              )[0];
  eidiot("$link_field not found!") unless $svc_x;
  $svcnum = $svc_x->svcnum;
}

my $old = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "svcnum not found!" unless $old;
#die "svcnum $svcnum already linked to package ". $old->pkgnum if $old->pkgnum;
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
%>
<!-- mason kludge -->
<%
  idiot($error);
}

%>
