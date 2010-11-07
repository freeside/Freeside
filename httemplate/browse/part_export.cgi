<% include("/elements/header.html", "Export Listing") %>

Provisioning services to external machines, databases and APIs.<BR><BR>

<A HREF="<% $p %>edit/part_export.cgi"><I>Add a new export</I></A><BR><BR>

<SCRIPT>
function part_export_areyousure(href) {
  if (confirm("Are you sure you want to delete this export?") == true)
    window.location.href = href;
}
</SCRIPT>

<% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

  <TR>
    <TH COLSPAN=2 CLASS="grid" BGCOLOR="#cccccc">Export</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Options</TH>
  </TR>

% foreach my $part_export ( sort { 
%     $a->getfield('exportnum') <=> $b->getfield('exportnum')
%   } qsearch('part_export',{})
% ) {
%   if ( $bgcolor eq $bgcolor1 ) {
%     $bgcolor = $bgcolor2;
%   } else {
%     $bgcolor = $bgcolor1;
%   }

    <TR>

      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>"><% $part_export->exportnum %></A></TD>

      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
% if( $part_export->exportname ) {
  <B><% $part_export->exportname %>:</B><BR>
% }
<% $part_export->exporttype %> to <% $part_export->machine %> (<A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>">edit</A>&nbsp;|&nbsp;<A HREF="javascript:part_export_areyousure('<% $p %>misc/delete-part_export.cgi?<% $part_export->exportnum %>')">delete</A>)</TD>

      <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
        <% itable() %>
%         my %opt = $part_export->options;
%         foreach my $opt ( keys %opt ) { 
  
            <TR>
              <TD ALIGN="right" VALIGN="top" WIDTH="33%"><% $opt %>:&nbsp;</TD>
              <TD ALIGN="left" WIDTH="67%"><% encode_entities($opt{$opt}) %></TD>
            </TR>
%         } 
  
        </TABLE>
      </TD>

    </TR>

% } 

</TABLE>

<% include('/elements/footer.html') %>

<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
</%init>
