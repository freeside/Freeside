<!-- mason kludge -->
<%

print header("Advertising source Listing", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)), "Where a customer heard about your service. Tracked for informational purposes.<BR><BR>", &table(), <<END;
      <TR>
        <TH COLSPAN=2>Advertising source</TH>
      </TR>
END

foreach my $part_referral ( sort { 
  $a->getfield('refnum') <=> $b->getfield('refnum')
} qsearch('part_referral',{}) ) {
  my($hashref)=$part_referral->hashref;
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{refnum}</A></TD>
        <TD><A HREF="${p}edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{referral}</A></TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="${p}edit/part_referral.cgi"><I>Add a new advertising source</I></A></TD>
      </TR>
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

%>
