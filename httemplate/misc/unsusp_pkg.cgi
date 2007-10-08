%
%
%#untaint pkgnum
%my ($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal pkgnum";
%my $pkgnum = $1;
%
%my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
%
%my $error = $cust_pkg->unsuspend;
%errorpage($error) if $error;
%
%print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));
%
%

