% if ( $error ) {
%   errorpage($error);
% } else {
<% $cgi->redirect($p. "view/svc_domain.cgi?". $domain_record->svcnum. '#dns') %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit domain nameservice');

#untaint recnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal recnum";
my $recnum = $1;

my $domain_record = qsearchs('domain_record',{'recnum'=>$recnum});

my $error = $domain_record->delete;

</%init>
