<!-- mason kludge -->
<%

print header('Access Number Listing', menubar(
  'Main Menu' => $p,
)), "Points of Presence<BR><BR>", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>City</TH>
        <TH>State</TH>
        <TH>Area code</TH>
        <TH>Exchange</TH>
        <TH>Local</TH>
      </TR>
END

foreach my $svc_acct_pop ( sort { 
  #$a->getfield('popnum') <=> $b->getfield('popnum')
  $a->state cmp $b->state || $a->city cmp $b->city
    || $a->ac <=> $b->ac || $a->exch <=> $b->exch || $a->loc <=> $b->loc
} qsearch('svc_acct_pop',{}) ) {
  my($hashref)=$svc_acct_pop->hashref;
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{popnum}</A></TD>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{city}</A></TD>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{state}</A></TD>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{ac}</A></TD>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{exch}</A></TD>
        <TD><A HREF="${p}edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{loc}</A></TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=5><A HREF="${p}edit/svc_acct_pop.cgi"><I>Add new Access Number</I></A></TD>
      </TR>
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

%>
