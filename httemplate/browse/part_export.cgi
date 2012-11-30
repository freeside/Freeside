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
        <% $part_export->label_html %>
        (<A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>">edit</A>&nbsp;|&nbsp;<A HREF="javascript:part_export_areyousure('<% $p %>misc/delete-part_export.cgi?<% $part_export->exportnum %>')">delete</A>)
      </TD>

      <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
        <% itable() %>
%         my %opt = $part_export->options;
%         my $defs = $part_export->info->{options};
%         my %multiples;
%         foreach my $opt (keys %$defs) { # is a Tie::IxHash
%           my $group = $defs->{$opt}->{multiple};
%           if ( $group ) {
%             my @values = split("\n", $opt{$opt});
%             $multiples{$group} ||= [];
%             push @{ $multiples{$group} }, [ $opt, @values ] if @values;
%             delete $opt{$opt};
%           } elsif (length($opt{$opt})) { # the normal case
%#         foreach my $opt ( keys %opt ) { 
  
            <TR>
              <TD ALIGN="right" VALIGN="top" WIDTH="33%"><% $opt %>:&nbsp;</TD>
              <TD ALIGN="left" WIDTH="67%"><% encode_entities($opt{$opt}) %></TD>
            </TR>
%             delete $opt{$opt};
%           }
%         }
%         # now any that are somehow not in the options list
%         foreach my $opt (keys %opt) {
%           if ( length($opt{$opt}) ) {
            <TR>
              <TD ALIGN="right" VALIGN="top" WIDTH="33%"><% $opt %>:&nbsp;</TD>
              <TD ALIGN="left" WIDTH="67%"><% encode_entities($opt{$opt}) %></TD>
            </TR>
%           }
%         }
%         # now show any multiple-option groups
%         foreach (sort keys %multiples) {
%           my $set = $multiples{$_};
            <TR><TD ALIGN="center" COLSPAN=2><TABLE CLASS="grid">
              <TR>
%             foreach my $col (@$set) {
                <TH><% shift @$col %></TH>
%             }
              </TR>
%           while ( 1 ) {
              <TR>
%             my $end = 1;
%             foreach my $col (@$set) {
                <TD><% shift @$col %></TD>
%               $end = 0 if @$col;
%             }
              </TR>
%             last if $end;
%           }
            </TABLE></TD></TR>
%         } #foreach keys %multiples

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
