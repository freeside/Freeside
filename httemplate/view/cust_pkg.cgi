<& /elements/header-cust_main.html,
     view    => 'packages',
     custnum => $cust_pkg->custnum,
&>

<& /elements/footer-cust_main.html &>
<%init>

my ($pkgnum) = $cgi->keywords;
$pkgnum =~ /^\d+$/ or die "invalid pkgnum '$pkgnum'";

my $cust_pkg = FS::cust_pkg->by_key($pkgnum) or die "pkgnum $pkgnum not found";

</%init>
