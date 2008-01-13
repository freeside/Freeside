%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "catchall.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit domain catchall');

$FS::svc_domain::whois_hack=1;

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum =$1;

my $old = qsearchs('svc_domain',{'svcnum'=>$svcnum}) if $svcnum;

my $new = new FS::svc_domain ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_domain'), qw( pkgnum svcpart ) )
} );

$new->setfield('action' => 'M');

my $error;
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

</%init>
