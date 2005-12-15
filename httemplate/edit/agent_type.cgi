<%

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

%>

<%= header("$action Agent Type", menubar(
  'Main Menu' => "$p",
  'View all agent types' => "${p}browse/agent_type.cgi",
))
%>

<% if ( $cgi->param('error') ) { %>
  <FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<FORM ACTION="<%= popurl(1) %>process/agent_type.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="typenum" VALUE="<%= $agent_type->typenum %>">
Agent Type #<%= $agent_type->typenum || "(NEW)" %>
<BR><BR>

Agent Type
<INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="<%= $agent_type->atype %>">
<BR><BR>

Select which packages agents of this type may sell to customers<BR>

<% foreach my $part_pkg (
     qsearch({ 'table'     => 'part_pkg',
               'hashref'   => { 'disabled' => '' },
               'select'    => 'part_pkg.*',
               'addl_from' => 'LEFT JOIN type_pkgs USING ( pkgpart )',
               'extra_sql' => ( $agent_type->typenum
                                  ? 'OR typenum = '. $agent_type->typenum
                                  : ''
                              ),
            })
   ) {
%>

  <BR>
  <INPUT TYPE="checkbox" NAME="pkgpart<%= $part_pkg->pkgpart %>" <%=
        qsearchs('type_pkgs',{
          'typenum' => $agent_type->typenum,
          'pkgpart' => $part_pkg->pkgpart,
        })
          ? 'CHECKED '
          : ''
  %> VALUE="ON">

  <A HREF="<%= $p %>edit/part_pkg.cgi?<%= $part_pkg->pkgpart %>"><%= $part_pkg->pkgpart %>: 
  <%= $part_pkg->pkg %> - <%= $part_pkg->comment %></A>
  <%= $part_pkg->disabled =~ /^Y/i ? ' (DISABLED)' : '' %>

<% } %>

<BR><BR>

<INPUT TYPE="submit" VALUE="<%= $agent_type->typenum ? "Apply changes" : "Add agent type" %>">

    </FORM>
  </BODY>
</HTML>
