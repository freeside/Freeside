<!-- $Id: svc_acct_sm.cgi,v 1.3 2002-01-30 14:18:09 ivan Exp $ -->
<%

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum =$1;

my $old = qsearchs('svc_acct_sm',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge domsvc and domuid
#$cgi->param('domsvc',(split(/:/, $cgi->param('domsvc') ))[0] );
#$cgi->param('domuid',(split(/:/, $cgi->param('domuid') ))[0] );

my $new = new FS::svc_acct_sm ( {
  map {
    ($_, scalar($cgi->param($_)));
  #} qw(svcnum pkgnum svcpart domuser domuid domsvc)
  } ( fields('svc_acct_sm'), qw( pkgnum svcpart ) )
} );

my $error = '';
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_acct_sm.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_acct_sm.cgi?$svcnum");
}

%>
