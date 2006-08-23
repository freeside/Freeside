%
%
%#untaint custnum
%$cgi->param('custnum') =~ /^(\d+)$/
%  or die 'illegal custnum '. $cgi->param('custnum');
%my $custnum = $1;
%$cgi->param('pkgpart') =~ /^(\d+)$/
%  or die 'illegal pkgpart '. $cgi->param('pkgpart');
%my $pkgpart = $1;
%
%my @cust_pkg = ();
%my $error = FS::cust_pkg::order($custnum, [ $pkgpart ], [], \@cust_pkg, );
%
%if ($error) {
%

<!-- mason kludge -->
%
%  eidiot($error);
%} else {
%  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum".
%                       "#cust_pkg". $cust_pkg[0]->pkgnum );
%}
%
%


