%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "agent_type.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "browse/agent_type.cgi") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $typenum = $cgi->param('typenum');
my $old = qsearchs('agent_type',{'typenum'=>$typenum}) if $typenum;

my $new = new FS::agent_type ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent_type')
} );

my $error;
if ( $typenum ) {
  $error = $new->replace($old);
} else {
  $error    = $new->insert;
  $typenum  = $new->getfield('typenum');
}

  $error ||= $new->process_m2m(
    'link_table'   => 'type_pkgs',
    'target_table' => 'part_pkg',
    'params'       => scalar($cgi->Vars)
  );

<%/init>
