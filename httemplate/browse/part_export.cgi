<% include("/elements/header.html","Export Listing", menubar( 'Main Menu' => "$p#sysadmin" )) %>
Provisioning services to external machines, databases and APIs.<BR><BR>
<A HREF="<% $p %>edit/part_export.cgi"><I>Add a new export</I></A><BR><BR>
<SCRIPT>
function part_export_areyousure(href) {
  if (confirm("Are you sure you want to delete this export?") == true)
    window.location.href = href;
}
</SCRIPT>

<% table() %>
  <TR>
    <TH COLSPAN=2>Export</TH>
    <TH>Options</TH>
  </TR>
% foreach my $part_export ( sort { 
%     $a->getfield('exportnum') <=> $b->getfield('exportnum')
%   } qsearch('part_export',{}) ) {
%

  <TR>
    <TD><A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>"><% $part_export->exportnum %></A></TD>
    <TD><% $part_export->exporttype %> to <% $part_export->machine %> (<A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>">edit</A>&nbsp;|&nbsp;<A HREF="javascript:part_export_areyousure('<% $p %>misc/delete-part_export.cgi?<% $part_export->exportnum %>')">delete</A>)</TD>
    <TD>
      <% itable() %>
% my %opt = $part_export->options;
%         foreach my $opt ( keys %opt ) { 

           <TR><TD><% $opt %></TD><TD><% encode_entities($opt{$opt}) %></TD></TR>
% } 

      </TABLE>
    </TD>
  </TR>
% } 


</TABLE>
</BODY>
</HTML>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
</%init>
