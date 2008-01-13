%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "agent.cgi?". $cgi->query_string ) %>
%} else { 
<% $cgi->redirect(popurl(3). "browse/agent.cgi") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agentnum = $cgi->param('agentnum');

my $old = qsearchs('agent',{'agentnum'=>$agentnum}) if $agentnum;

my $new = new FS::agent ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent')
} );

my $error;
if ( $agentnum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $agentnum=$new->getfield('agentnum');
}

</%init>
