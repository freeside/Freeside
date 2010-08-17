<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit domain nameservice');

my $svcnum = scalar($cgi->param('svcnum'));

my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svcnum })
  or die 'unknown svc_domain.svcnum';

my $error = $svc_domain->insert_defaultrecords;

</%init>
