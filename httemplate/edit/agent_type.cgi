<% include("/elements/header.html","$action Agent Type", menubar(
  'View all agent types' => "${p}browse/agent_type.cgi",
))
%>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/agent_type.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="typenum" VALUE="<% $agent_type->typenum %>">
Agent Type #<% $agent_type->typenum || "(NEW)" %>
<BR>

Agent Type
<INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="<% $agent_type->atype %>">
<BR><BR>

Select which packages agents of this type may sell to customers<BR>
<% ntable("#cccccc", 2) %><TR><TD>
<% include('/elements/checkboxes-table.html',
              'source_obj'    => $agent_type,
              'link_table'    => 'type_pkgs',
              'target_table'  => 'part_pkg',
              'name_callback' => sub { $_[0]->pkg_comment(nopkgpart => 1); },
              'target_link'   => $p.'edit/part_pkg.cgi?',
              'disable-able'  => 1,

           )
%>
</TD></TR></TABLE>
<BR>

<INPUT TYPE="submit" VALUE="<% $agent_type->typenum ? "Apply changes" : "Add agent type" %>">

    </FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my($agent_type);
if ( $cgi->param('error') ) {
  $agent_type = new FS::agent_type ( {
    map { $_, scalar($cgi->param($_)) } fields('agent')
  } );
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $agent_type=qsearchs('agent_type',{'typenum'=>$1});
} else { #adding
  $agent_type = new FS::agent_type {};
}
my $action = $agent_type->typenum ? 'Edit' : 'Add';

</%init>
