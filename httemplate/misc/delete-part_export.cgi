% if ( $error ) {
%   errorpage($error);
% } else {
<% $cgi->redirect($p. "browse/part_export.cgi") %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#untaint exportnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal exportnum";
my $exportnum = $1;

my $part_export = qsearchs('part_export',{'exportnum'=>$exportnum});

my $error = $part_export->delete;

</%init>
