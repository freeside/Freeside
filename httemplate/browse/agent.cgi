<%
#
# $Id: agent.cgi,v 1.1 2001-07-30 07:36:03 ivan Exp $
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
# Revision 1.1  2001-07-30 07:36:03  ivan
# templates!!!
#
# Revision 1.13  1999/04/09 04:22:34  ivan
# also table()
#
# Revision 1.12  1999/04/09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.11  1999/01/20 09:43:16  ivan
# comment out future UI code (but look at it, it's neat!)
#
# Revision 1.10  1999/01/19 05:13:24  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.9  1999/01/18 09:41:14  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.8  1999/01/18 09:22:26  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.7  1998/12/17 05:25:16  ivan
# fix visual and other bugs
#
# Revision 1.6  1998/11/23 05:29:46  ivan
# use CGI::Carp
#
# Revision 1.5  1998/11/23 05:27:31  ivan
# to eliminate warnings
#
# Revision 1.4  1998/11/20 08:50:36  ivan
# s/CGI::Base/CGI.pm, visual fixes
#
# Revision 1.3  1998/11/08 10:11:02  ivan
# CGI.pm
#
# Revision 1.2  1998/11/07 10:24:22  ivan
# don't use depriciated FS::Bill and FS::Invoice, other miscellania
#

use strict;
use vars qw( $ui $cgi $p $agent );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
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
