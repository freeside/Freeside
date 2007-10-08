%
%
%#untaint exportnum
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/ || die "Illegal exportnum";
%my $exportnum = $1;
%
%my $part_export = qsearchs('part_export',{'exportnum'=>$exportnum});
%
%my $error = $part_export->delete;
%errorpage($error) if $error;
%
%print $cgi->redirect($p. "browse/part_export.cgi");
%
%

