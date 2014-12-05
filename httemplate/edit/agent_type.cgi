<% include("/elements/header.html","$action Agent Type", menubar(
  'View all agent types' => "${p}browse/agent_type.cgi",
))
%>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/agent_type.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="typenum" VALUE="<% $agent_type->typenum %>">

<FONT CLASS="fsinnerbox-title">
Agent Type #<% $agent_type->typenum || "(NEW)" %>
</FONT>

<TABLE CLASS="fsinnerbox">

  <TR>
    <TH ALIGN="right">Agent Type</TH>
    <TD><INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="<% $agent_type->atype %>"></TD>
  </TR>

  <TR>
    <TH ALIGN="right">Disable</TH>
    <TD><INPUT TYPE="checkbox" NAME="disabled" VALUE="Y" <% $agent_type->disabled eq 'Y' ? ' CHECKED' : '' %>></TD>
  </TR>

<TABLE>
<BR>

<FONT CLASS="fsinnerbox-title">
Package definitions that agents of this type can sell
</FONT>

<TABLE CLASS="fsinnerbox"><TR><TD>
<% include('/elements/checkboxes-table.html',
              'source_obj'    => $agent_type,
              'link_table'    => 'type_pkgs',
              'target_table'  => 'part_pkg',
              'name_callback' => sub { encode_entities( $_[0]->pkg_comment(nopkgpart => 1) ); },
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
