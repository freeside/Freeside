<%

#Begin silliness
#
#use FS::UI::CGI;
#use FS::UI::agent;
#
#$ui = new FS::UI::agent;
#$ui->browse;
#exit;
#__END__
#End silliness

print header('Agent Listing', menubar(
  'Main Menu'   => $p,
  'Agent Types' => $p. 'browse/agent_type.cgi',
#  'Add new agent' => '../edit/agent.cgi'
)), <<END;
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).<BR><BR>
END
print &table(), <<END;
      <TR>
        <TH COLSPAN=2>Agent</TH>
        <TH>Type</TH>
        <TH><FONT SIZE=-1>Freq. (unimp.)</FONT></TH>
        <TH><FONT SIZE=-1>Prog. (unimp.)</FONT></TH>
      </TR>
END
#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
#        <TH>Agent</TH>

foreach my $agent ( sort { 
  $a->getfield('agentnum') <=> $b->getfield('agentnum')
} qsearch('agent',{}) ) {
  my($hashref)=$agent->hashref;
  my($typenum)=$hashref->{typenum};
  my($agent_type)=qsearchs('agent_type',{'typenum'=>$typenum});
  my($atype)=$agent_type->getfield('atype');
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/agent.cgi?$hashref->{agentnum}">
          $hashref->{agentnum}</A></TD>
        <TD><A HREF="${p}edit/agent.cgi?$hashref->{agentnum}">
          $hashref->{agent}</A></TD>
        <TD><A HREF="${p}edit/agent_type.cgi?$typenum">$atype</A></TD>
        <TD>$hashref->{freq}</TD>
        <TD>$hashref->{prog}</TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="${p}edit/agent.cgi"><I>Add a new agent</I></A></TD>
        <TD><A HREF="${p}edit/agent_type.cgi"><I>Add a new agent type</I></A></TD>
      </TR>
    </TABLE>

  </BODY>
</HTML>
END

%>
