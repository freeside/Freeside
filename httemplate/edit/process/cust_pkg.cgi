<%

my $error = '';

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/;
my $custnum = $1;

my @remove_pkgnums = map {
  /^(\d+)$/ or die "Illegal remove_pkg value!";
  $1;
} $cgi->param('remove_pkg');

my @pkgparts;
foreach my $pkgpart ( map /^pkg(\d+)$/ ? $1 : (), $cgi->param ) {
  if ( $cgi->param("pkg$pkgpart") =~ /^(\d+)$/ ) {
    my $num_pkgs = $1;
    while ( $num_pkgs-- ) {
      push @pkgparts,$pkgpart;
    }
  } else {
    $error = "Illegal quantity";
    last;
  }
}

$error ||= FS::cust_pkg::order($custnum,\@pkgparts,\@remove_pkgnums);

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_pkg.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}

%>
