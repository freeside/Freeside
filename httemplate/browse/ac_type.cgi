<!-- mason kludge -->
<%

print header('Access Concentrator Types', menubar(
  'Main Menu' => $p,
  'Access Concentrators' => $p. 'browse/ac.cgi',
)) %>
<BR>
<A HREF="<%= $p %>edit/ac_type.cgi"><I>Add new AC Type</I></A><BR><BR>
<%= table() %>
      <TR>
        <TH></TH>
        <TH>Type</TH>
        <TH>Fields</TH>
      </TR>

<%
foreach my $ac_type ( qsearch('ac_type',{}) ) {
  my($hashref)=$ac_type->hashref;
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/ac_type.cgi?$hashref->{actypenum}">
          $hashref->{actypenum}</A></TD>
        <TD><A HREF="${p}edit/ac_type.cgi?$hashref->{actypenum}">
          $hashref->{actypename}</A></TD>
        <TD>
END

  foreach ( qsearch('part_ac_field', { actypenum => $hashref->{actypenum} }) ) {
    my ($part_ac_field) = $_->hashref;
    print $part_ac_field->{'name'} .
          ' (' . $part_ac_field->{'ut_type'} . ')<BR>';
  }

}

print <<END;
       </TD>
      </TR>
      <TR>
      </TR>
    </TABLE>
  </BODY>
</HTML>
END

%>
