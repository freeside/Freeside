%unless ( ref($error) ) {
%  $cgi->param('error'. $error );
<% $cgi->redirect(popurl(3). "edit/reg_code.cgi?". $cgi->query_string ) %>
% } else { 

<% include("/elements/header.html","$num registration codes generated for ". $agent->agent, menubar(
  'View all agents' => popurl(3). 'browse/agent.cgi',
) ) %>

<PRE><FONT SIZE="+1">
% foreach my $code ( @$error ) { 
  <% $code %>
% } 
</FONT></PRE>

<% include('/elements/footer.html') %>
% } 
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

$cgi->param('agentnum') =~ /^(\d+)$/
  or errorpage('illegal agentnum '. $cgi->param('agentnum'));
my $agentnum = $1;
my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );

my $error = '';

my $num = 0;
if ( $cgi->param('num') =~ /^\s*(\d+)\s*$/ ) {
  $num = $1;
} else {
  $error = 'Illegal number of codes: '. $cgi->param('num');
}

my @pkgparts = 
  map  { /^pkgpart(.*)$/; $1 }
  grep { $cgi->param($_) }
  grep { /^pkgpart/ }
  $cgi->param;

$error ||= $agent->generate_reg_codes($num, \@pkgparts);

</%init>

