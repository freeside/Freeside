<%
#<!-- $Id: agent.cgi,v 1.3 2001-08-21 09:34:13 ivan Exp $ -->

use strict;
use vars qw( $ui $cgi $p $agent );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar table popurl);
use FS::agent;
use FS::agent_type;

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

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header('Agent Listing', menubar(
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

foreach $agent ( sort { 
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
        <TD COLSPAN=2><A HREF="${p}edit/agent.cgi"><I>Add new agent</I></A></TD>
        <TD><A HREF="${p}edit/agent_type.cgi"><I>Add new agent type</I></A></TD>
      </TR>
    </TABLE>

  </BODY>
</HTML>
END

%>
