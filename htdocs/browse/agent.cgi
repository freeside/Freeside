#!/usr/bin/perl -Tw
#
# $Id: agent.cgi,v 1.4 1998-11-20 08:50:36 ivan Exp $
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
#
# $Log: agent.cgi,v $
# Revision 1.4  1998-11-20 08:50:36  ivan
# s/CGI::Base/CGI.pm, visual fixes
#
# Revision 1.3  1998/11/08 10:11:02  ivan
# CGI.pm
#
# Revision 1.2  1998/11/07 10:24:22  ivan
# don't use depriciated FS::Bill and FS::Invoice, other miscellania
#

use strict;
use CGI;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar table popurl);
use FS::agent;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

print $cgi->header, header('Agent Listing', menubar(
  'Main Menu'   => popurl(2),
  'Agent Types' => 'agent_type.cgi',
#  'Add new agent' => '../edit/agent.cgi'
)), <<END;
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).<BR><BR>
END
print table, <<END;
      <TR>
        <TH COLSPAN=2>Agent</TH>
        <TH>Type</TH>
        <TH><FONT SIZE=-1>Freq. (unimp.)</FONT></TH>
        <TH><FONT SIZE=-1>Prog. (unimp.)</FONT></TH>
      </TR>
END
#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
#        <TH>Agent</TH>

my($agent);
my($p)=popurl(2);
foreach $agent ( sort { 
  $a->getfield('agentnum') <=> $b->getfield('agentnum')
} qsearch('agent',{}) ) {
  my($hashref)=$agent->hashref;
  my($typenum)=$hashref->{typenum};
  my($agent_type)=qsearchs('agent_type',{'typenum'=>$typenum});
  my($atype)=$agent_type->getfield('atype');
  print <<END;
      <TR>
        <TD><A HREF="$p/edit/agent.cgi?$hashref->{agentnum}">
          $hashref->{agentnum}</A></TD>
        <TD><A HREF="$p/edit/agent.cgi?$hashref->{agentnum}">
          $hashref->{agent}</A></TD>
        <TD><A HREF="$p/edit/agent_type.cgi?$typenum">$atype</A></TD>
        <TD>$hashref->{freq}</TD>
        <TD>$hashref->{prog}</TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="$p/edit/agent.cgi"><I>Add new agent</I></A></TD>
        <TD><A HREF="$p/edit/agent_type.cgi"><I>Add new agent type</I></A></TD>
      </TR>
    </TABLE>

  </BODY>
</HTML>
END

