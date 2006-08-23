%
%
%my $error = '';
%
%#untaint custnum
%$cgi->param('custnum') =~ /^(\d+)$/;
%my $custnum = $1;
%
%my @remove_pkgnums = map {
%  /^(\d+)$/ or die "Illegal remove_pkg value!";
%  $1;
%} $cgi->param('remove_pkg');
%
%my $error_redirect;
%my @pkgparts;
%if ( $cgi->param('new_pkgpart') =~ /^(\d+)$/ ) { #came from misc/change_pkg.cgi
%  $error_redirect = "misc/change_pkg.cgi";
%  @pkgparts = ($1);
%} else { #came from edit/cust_pkg.cgi
%  $error_redirect = "edit/cust_pkg.cgi";
%  foreach my $pkgpart ( map /^pkg(\d+)$/ ? $1 : (), $cgi->param ) {
%    if ( $cgi->param("pkg$pkgpart") =~ /^(\d+)$/ ) {
%      my $num_pkgs = $1;
%      while ( $num_pkgs-- ) {
%        push @pkgparts,$pkgpart;
%      }
%    } else {
%      $error = "Illegal quantity";
%      last;
%    }
%  }
%}
%
%$error ||= FS::cust_pkg::order($custnum,\@pkgparts,\@remove_pkgnums);
%
%if ($error) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(3). $error_redirect. '?'. $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
%}
%
%

