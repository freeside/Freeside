<!-- mason kludge -->
<%

#if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
#  $cgi->param('clone', $1);
#} else {
#  $cgi->param('clone', '');
#}

my($query) = $cgi->keywords;
my $action = '';
my $part_export = '';
if ( $cgi->param('error') ) {
  $part_export = new FS::part_export ( {
    map { $_, scalar($cgi->param($_)) } fields('part_export')
  } );
} elsif ( $query =~ /^(\d+)$/ ) {
  $part_export = qsearchs('part_export', { 'exportnum' => $1 } );
} else {
  $part_export = new FS::part_export;
}
$action ||= $part_export->exportnum ? 'Edit' : 'Add';

#my $exports = FS::part_export::export_info($svcdb);
my $exports = FS::part_export::export_info();

my %layers = map { $_ => "$_ - ". $exports->{$_}{desc} } keys %$exports;
$layers{''}='';

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => $part_export->exporttype,
  'options'        => \%layers,
  'form_name'      => 'dummy',
  'form_action'    => 'process/part_export.cgi',
  'form_text'      => [qw( exportnum machine )],
#  'form_checkbox'  => [qw()],
  'html_between'    => "</TD></TR></TABLE>\n",
  'layer_callback'  => sub {
    my $layer = shift;
    my $html = qq!<INPUT TYPE="hidden" NAME="exporttype" VALUE="$layer">!.
               ntable("#cccccc",2);
    foreach my $option ( keys %{$exports->{$layer}{options}} ) {
#    foreach my $option ( qw(url login password groupID ) ) {
      my $optinfo = $exports->{$layer}{options}{$option};
      my $label = $optinfo->{label};
      my $value = $cgi->param($option) || $part_export->option($option);
      $html .= qq!<TR><TD ALIGN="right">$label</TD><TD>!.
               qq!<TD><INPUT TYPE="text" NAME="$option" VALUE="$value"></TD>!.
               '</TR>';
    }
    $html .= '</TABLE>';

    $html .= '<INPUT TYPE="hidden" NAME="options" VALUE="'.
             join(',', keys %{$exports->{$layer}{options}} ). '">';

    $html .= '<INPUT TYPE="hidden" NAME="nodomain" VALUE="'.
             $exports->{$layer}{nodomain}. '">';

    $html .= '<INPUT TYPE="submit" VALUE="'.
             ( $part_export->exportnum ? "Apply changes" : "Add export" ).
             '">';

    $html;
  },
);

%>
<%= header("$action Export", menubar(
  'Main Menu' => popurl(2),
), ' onLoad="visualize()"')
%>

<% if ( $cgi->param('error') ) { %>
  <FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
  <BR><BR>
<% } %>

<FORM NAME="dummy">
<INPUT TYPE="hidden" NAME="exportnum" VALUE="<%= $part_export->exportnum %>">

<%= ntable("#cccccc",2) %>
<TR>
  <TD ALIGN="right">Export host</TD>
  <TD>
    <INPUT TYPE="text" NAME="machine" VALUE="<%= $part_export->machine %>">
  </TD>
</TR>
<TR>
  <TD ALIGN="right">Export</TD>
  <TD><%= $widget->html %>
</BODY>
</HTML>

