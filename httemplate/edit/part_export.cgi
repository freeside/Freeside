<!-- mason kludge -->
<%

#if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
#  $cgi->param('clone', $1);
#} else {
#  $cgi->param('clone', '');
#}
#if ( $cgi->param('svcpart') && $cgi->param('svcpart') =~ /^(\d+)$/ ) {
#  $cgi->param('svcpart', $1);
#} else {
#  $cgi->param('svcpart', '');
#}

my($query) = $cgi->keywords;
my $action = '';
my $part_export = '';
my $options = {};
if ( $cgi->param('error') ) {
  $part_export = new FS::part_export ( {
    map { $_, scalar($cgi->param($_)) } fields('part_export')
  } );
}

warn "***$query***";
if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
  $action = 'Add';
  my $old_part_export = qsearchs('part_export', { 'exportnum' => $1 } );
  unless ( $part_export ) {
    ($part_export, $options) = $old_part_export->clone;
  }
} elsif ( $cgi->param('new_with_svcpart') 
          && $cgi->param('new_with_svcpart') =~ /^(\d+)$/ ) {
  $part_export ||= new FS::part_export ( { 'svcpart' => $1 } );
} elsif ( $query =~ /^(\d+)$/ ) {
  $part_export ||= qsearchs('part_export', { 'exportnum' => $1 } );
}
$action ||= $part_export->exportnum ? 'Edit' : 'Add';

my @types = qw(shell bsdshell textradius sqlradius cp);

%>
<%= header("$action Export", menubar(
  'Main Menu' => popurl(2),
), ' onLoad="visualize()"')
%>

<% if ( $cgi->param('error') ) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<FORM ACTION="<%= popurl(1) %>process/part_export.cgi" METHOD=POST>
<% #print '<FORM NAME="dummy">'; %>

<%= ntable("#cccccc",2) %>
<TR>
  <TD ALIGN="right">Service</TD>
  <TD BGCOLOR="#ffffff">
    <%= $part_export->svcpart %> - <%= $part_export->part_svc->svc %>
  </TD>
</TR>
<TR>
  <TD ALIGN="right">Export</TD>
  <TD><SELECT NAME="exporttype"><OPTION></OPTION>
<% foreach my $type ( @types ) { %>
    <OPTION><%= $type %></OPTION>
<% } %>
  </SELECT></TD>
</TR>
<TR>
  <TD ALIGN="right">Export host</TD>
  <TD>
    <INPUT TYPE="text" NAME="machine" VALUE="<%= $part_export->machine %>">
  </TD>
</TR>
</TABLE>
</FORM>
</BODY>
</HTML>

