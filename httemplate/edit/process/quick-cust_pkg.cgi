<%

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/
  or eidiot 'illegal custnum '. $cgi->param('custnum');
my $custnum = $1;
$cgi->param('pkgpart') =~ /^(\d+)$/
  or eidiot 'illegal pkgpart '. $cgi->param('pkgpart');
my $pkgpart = $1;

my @cust_pkg = ();
my $error = FS::cust_pkg::order($custnum, [ $pkgpart ], [], \@cust_pkg, );

if ($error) {
  eidiot($error);
} else {
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?". $cust_pkg[0]->pkgnum );
}

%>

