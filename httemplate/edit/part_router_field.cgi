<!-- mason kludge -->
<%
my ($routerfieldpart, $part_router_field);

if ( $cgi->param('error') ) {
  $part_router_field = new FS::part_router_field ( {
    map { $_, scalar($cgi->param($_)) } fields('part_router_field')});
  $routerfieldpart = $part_router_field->routerfieldpart;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $routerfieldpart=$1;
    $part_router_field=qsearchs('part_router_field',
        {'routerfieldpart' => $routerfieldpart})
      or die "Unknown routerfieldpart!";
  
  } else { #adding
    $part_router_field = new FS::part_router_field({});
  }
}
my $action = $part_router_field->routerfieldpart ? 'Edit' : 'Add';

my $p1 = popurl(1);
print header("$action Router Extended Field Definition",
             menubar('Main Menu' => $p,
                     'View all Extended Fields' => $p. 'browse/generic.cgi?part_router_field')
            );

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
%>
<FORM ACTION="<%=$p1%>process/generic.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="table" VALUE="part_router_field">
<INPUT TYPE="hidden" NAME="routerfieldpart" VALUE="<%=
  $routerfieldpart%>">
Field #<B><%=$routerfieldpart or "(NEW)"%></B><BR><BR>

<%=ntable("#cccccc",2)%>
  <TR>
    <TD ALIGN="right">Name</TD>
    <TD><INPUT TYPE="text" NAME="name" MAXLENGTH=15 VALUE="<%=
    $part_router_field->name%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Length</TD>
    <TD><INPUT TYPE="text" NAME="length" MAXLENGTH=4 VALUE="<%=
    $part_router_field->length%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">check_block</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="check_block"><%=
    $part_router_field->check_block%></TEXTAREA></TD>
  </TR>
  <TR>
    <TD ALIGN="right">list_source</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="list_source"><%=
    $part_router_field->list_source%></TEXTAREA></TD>
  </TR>
</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">

</FORM>

<BR><BR>
<FONT SIZE=-2>If you don't understand what <I>check_block</I> and 
<I>list_source</I> mean, <B>LEAVE THEM BLANK</B>.  We mean it.</FONT>


</BODY>
</HTML>
