<!-- mason kludge -->
<%= header("Agent Type Listing", menubar(
  'Main Menu' => $p,
  'Agents'    => $p. 'browse/agent.cgi',
)) %>
Agent types define groups of packages that you can then assign to particular
agents.<BR><BR>
<A HREF="<%= $p %>edit/agent_type.cgi"><I>Add a new agent type</I></A><BR><BR>

<%= table() %>
<TR>
  <TH COLSPAN=2>Agent Type</TH>
  <TH COLSPAN=2>Packages</TH>
</TR>

<% 
foreach my $agent_type ( sort { 
  $a->getfield('typenum') <=> $b->getfield('typenum')
} qsearch('agent_type',{}) ) {
  my $hashref = $agent_type->hashref;
  #more efficient to do this with SQL...
  my @type_pkgs = grep { ! $_->part_pkg->disabled }
                       qsearch('type_pkgs',{'typenum'=> $hashref->{typenum} });
  my $rowspan = scalar(@type_pkgs);
  $rowspan = int($rowspan/2+0.5) ;
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/agent_type.cgi?$hashref->{typenum}">
          $hashref->{typenum}
        </A></TD>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/agent_type.cgi?$hashref->{typenum}">$hashref->{atype}</A></TD>
END

  my($type_pkgs);
  my($tdcount) = -1 ;
  foreach $type_pkgs ( @type_pkgs ) {
    my($pkgpart)=$type_pkgs->getfield('pkgpart');
    my($part_pkg) = qsearchs('part_pkg',{'pkgpart'=> $pkgpart });
    print qq!<TR>! if ($tdcount == 0) ;
    $tdcount = 0 if ($tdcount == -1) ;
    print qq!<TD><A HREF="${p}edit/part_pkg.cgi?$pkgpart">!,
          $part_pkg->getfield('pkg'),"</A></TD>";
    $tdcount ++ ;
    if ($tdcount == 2)
    {
	print qq!</TR>\n! ;
	$tdcount = 0 ;
    }
  }

  print "</TR>";
}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
