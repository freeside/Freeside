#!/usr/bin/perl -Tw
#
# agent.cgi: browse agent
#
# ivan@sisd.com 97-dec-12
#
# changes to allow pages to load from a relative location in the web tree.
#	bmccane@maxbaud.net	98-mar-25
#
# changed 'type' to 'atype' because type is reserved word in Pg6.3
#	bmccane@maxbaud.net	98-apr-3
#
# agent type was linking to wrong cgi ivan@sisd.com 98-jul-18
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.
print header('Agent Listing', menubar(
  'Main Menu' => '../',
  'Add new agent' => '../edit/agent.cgi'
)), <<END;
    <BR>
    Click on agent number to edit.
    <TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>Agent #</FONT></TH>
        <TH>Agent</TH>
        <TH>Type</TH>
        <TH><FONT SIZE=-1>Freq. (unimp.)</FONT></TH>
        <TH><FONT SIZE=-1>Prog. (unimp.)</FONT></TH>
      </TR>
END

my($agent);
foreach $agent ( sort { 
  $a->getfield('agentnum') <=> $b->getfield('agentnum')
} qsearch('agent',{}) ) {
  my($hashref)=$agent->hashref;
  my($typenum)=$hashref->{typenum};
  my($agent_type)=qsearchs('agent_type',{'typenum'=>$typenum});
  my($atype)=$agent_type->getfield('atype');
  print <<END;
      <TR>
        <TD><A HREF="../edit/agent.cgi?$hashref->{agentnum}">
          $hashref->{agentnum}</A></TD>
        <TD>$hashref->{agent}</TD>
        <TD><A HREF="../edit/agent_type.cgi?$typenum">$atype</A></TD>
        <TD>$hashref->{freq}</TD>
        <TD>$hashref->{prog}</TD>
      </TR>
END

}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

