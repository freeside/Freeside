<!-- mason kludge -->
<%= header('Access Concentrator Listing', menubar(
  'Main Menu'   => $p,
  'Access Concentrator Types' => $p. 'browse/ac_type.cgi',
)) %>
<BR>
<A HREF="<%= $p %>edit/ac.cgi"><I>Add a new Access Concentrator</I></A><BR><BR>

<%= table() %>
<TR>
  <TH COLSPAN=2>AC</TH>
  <TH>AC Type</TH>
  <TH>Fields</TH>
  <TH>Network/Mask</TH>
</TR>
<% 

foreach my $ac ( qsearch('ac',{}) ) {
  my($hashref)=$ac->hashref;
  my($actypenum)=$hashref->{actypenum};
  my($ac_type)=qsearchs('ac_type',{'actypenum'=>$actypenum});
  my($actypename)=$ac_type->getfield('actypename');
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/ac.cgi?$hashref->{acnum}">
          $hashref->{acnum}</A></TD>
        <TD><A HREF="${p}edit/ac.cgi?$hashref->{acnum}">
          $hashref->{acname}</A></TD>
        <TD><A HREF="${p}edit/ac_type.cgi?$actypenum">$actypename</A></TD>
        <TD>
END

  foreach my $ac_field ( qsearch('ac_field', { acnum => $hashref->{acnum} }) ) {
    my $part_ac_field = qsearchs('part_ac_field',
                         { acfieldpart => $ac_field->getfield('acfieldpart') });
    print $part_ac_field->getfield('name') . ' ';
    print $ac_field->getfield('value') . '<BR>';
  }
  print '</TD><TD>';

  foreach (qsearch('ac_block', { acnum => $hashref->{acnum} })) {
    my $net_addr = new NetAddr::IP($_->getfield('ip_gateway'),
                                   $_->getfield('ip_netmask'));
    print $net_addr->network->addr . '/' . $net_addr->network->mask . '<BR>';
  }

  print "<TR>\n";

}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
