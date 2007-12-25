%
%my ($vfieldpart, $part_virtual_field);
%
%if ( $cgi->param('error') ) {
%  $part_virtual_field = new FS::part_virtual_field ( {
%    map { $_, scalar($cgi->param($_)) } fields('part_virtual_field')});
%  $vfieldpart = $part_virtual_field->vfieldpart;
%} else {
%  my($query) = $cgi->keywords;
%  if ( $query =~ /^(\d+)$/ ) { #editing
%    $vfieldpart=$1;
%    $part_virtual_field=qsearchs('part_virtual_field',
%        {'vfieldpart' => $vfieldpart})
%      or die "Unknown vfieldpart!";
%  
%  } else { #adding
%    $part_virtual_field = new FS::part_virtual_field({});
%  }
%}
%my $action = $part_virtual_field->vfieldpart ? 'Edit' : 'Add';
%
%my $p1 = popurl(1);
%
%
<% include('/elements/header.html', "$action Virtual Field Definition") %>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/generic.cgi" METHOD="POST">

<INPUT TYPE="hidden" NAME="table" VALUE="part_virtual_field">
<INPUT TYPE="hidden" NAME="redirect_ok" 
    VALUE="<%popurl(2)%>browse/part_virtual_field.cgi">
<INPUT TYPE="hidden" NAME="vfieldpart" VALUE="<%
  $vfieldpart%>">
Field #<B><%$vfieldpart or "(NEW)"%></B><BR><BR>

<%ntable("#cccccc",2)%>
  <TR>
    <TD ALIGN="right">Name</TD>
    <TD><INPUT TYPE="text" NAME="name" MAXLENGTH=32 VALUE="<%
    $part_virtual_field->name%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Table</TD>
    <TD>
% if ($action eq 'Add') { 

      <SELECT SIZE=1 NAME="dbtable">
%
%        my $dbdef = dbdef;  # ick
%        #foreach my $dbtable (sort { $a cmp $b } $dbdef->tables) {
%        foreach my $dbtable (qw( svc_broadband router )) {
%          if ($dbtable !~ /^h_/
%          and $dbdef->table($dbtable)->primary_key) { 

            <OPTION VALUE="<%$dbtable%>"><%$dbtable%></OPTION>
%
%          }
%        }
%      
</SELECT>
%
%    } else { # Edit
%    
<%$part_virtual_field->dbtable%>
    <INPUT TYPE="hidden" NAME="dbtable" VALUE="<%$part_virtual_field->dbtable%>">
% } 

    </TD>
  <TR>
    <TD ALIGN="right">Label</TD>
    <TD><INPUT TYPE="text" NAME="label" MAXLENGTH="80" VALUE="<%
    $part_virtual_field->label%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Length</TD>
    <TD><INPUT TYPE="text" NAME="length" MAXLENGTH=4 VALUE="<%
    $part_virtual_field->length%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">Check</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="check_block"><%
    $part_virtual_field->check_block%></TEXTAREA></TD>
  </TR>
  <TR>
    <TD ALIGN="right">List source</TD>
    <TD><TEXTAREA COLS="20" ROWS="4" NAME="list_source"><%
    $part_virtual_field->list_source%></TEXTAREA></TD>
  </TR>
</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">

</FORM>

<BR>
<FONT SIZE=-2>If you don't understand what <I>check_block</I> and 
<I>list_source</I> mean, <B>LEAVE THEM BLANK</B>.  We mean it.</FONT>

<% include('/elements/footer.html') %>
