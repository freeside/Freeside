<!-- mason kludge -->
<%
my ($sbfieldpart, $part_sb_field);

if ( $cgi->param('error') ) {
  $part_sb_field = new FS::part_sb_field ( {
    map { $_, scalar($cgi->param($_)) } fields('part_sb_field')});
  $sbfieldpart = $part_sb_field->sbfieldpart;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $sbfieldpart=$1;
    $part_sb_field=qsearchs('part_sb_field',
        {'sbfieldpart' => $sbfieldpart})
      or die "Unknown sbfieldpart!";
  
  } else { #adding
    $part_sb_field = new FS::part_sb_field({});
  }
}
my $action = $part_sb_field->sbfieldpart ? 'Edit' : 'Add';

my $p1 = popurl(1);
print header("$action svc_broadband Extended Field Definition", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
%>
<FORM ACTION="<%=$p1%>process/generic.cgi" METHOD="POST">

<INPUT TYPE="hidden" NAME="table" VALUE="part_sb_field">
<INPUT TYPE="hidden" NAME="redirect_ok" 
    VALUE="<%=popurl(2)%>browse/part_sb_field.cgi">
<INPUT TYPE="hidden" NAME="sbfieldpart" VALUE="<%=
  $sbfieldpart%>">
Field #<B><%=$sbfieldpart or "(NEW)"%></B><BR><BR>

<%=ntable("#cccccc",2)%>
  <TR>
    <TD ALIGN="right">Name</TD>
    <TD><INPUT TYPE="text" NAME="name" MAXLENGTH=15 VALUE="<%=
    $part_sb_field->name%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Length</TD>
    <TD><INPUT TYPE="text" NAME="length" MAXLENGTH=4 VALUE="<%=
    $part_sb_field->length%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Service</TD>
    <TD><SELECT SIZE=1 NAME="svcpart"><%
      foreach my $part_svc (qsearch('part_svc', {svcdb => 'svc_broadband'})) {
        %><OPTION VALUE="<%=$part_svc->svcpart%>"<%=
	  ($part_svc->svcpart == $part_sb_field->svcpart) ? ' SELECTED' : ''%>">
	  <%=$part_svc->svc%>
      <% } %>
      </SELECT></TD>
  <TR>
    <TD ALIGN="right">check_block</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="check_block"><%=
    $part_sb_field->check_block%></TEXTAREA></TD>
  </TR>
  <TR>
    <TD ALIGN="right">list_source</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="list_source"><%=
    $part_sb_field->list_source%></TEXTAREA></TD>
  </TR>
</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">

</FORM>

<BR><BR>
<FONT SIZE=-2>If you don't understand what <I>check_block</I> and 
<I>list_source</I> mean, <B>LEAVE THEM BLANK</B>.  We mean it.</FONT>


</BODY>
</HTML>
