<%
#<!-- $Id: agent.cgi,v 1.3 2001-08-29 09:11:30 ivan Exp $ -->

use strict;
use vars qw ( $cgi $agent $action $hashref $p $agent_type );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl ntable);
use FS::Record qw(qsearch qsearchs fields);
use FS::agent;
use FS::agent_type;

$cgi = new CGI;

&cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $agent = new FS::agent ( {
    map { $_, scalar($cgi->param($_)) } fields('agent')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $agent = qsearchs( 'agent', { 'agentnum' => $1 } );
} else { #adding
  $agent = new FS::agent {};
}
$action = $agent->agentnum ? 'Edit' : 'Add';
$hashref = $agent->hashref;

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("$action Agent", menubar(
  'Main Menu' => $p,
  'View all agents' => $p. 'browse/agent.cgi',
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print '<FORM ACTION="', popurl(1), 'process/agent.cgi" METHOD=POST>',
      qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$hashref->{agentnum}">!,
      "Agent #", $hashref->{agentnum} ? $hashref->{agentnum} : "(NEW)";

print &ntable("#cccccc", 2, ''), <<END;
<TR>
  <TH ALIGN="right">Agent</TH>
  <TD><INPUT TYPE="text" NAME="agent" SIZE=32 VALUE="$hashref->{agent}"></TD>
</TR>
<TR>
  <TH ALIGN="right">Agent type</TH>
  <TD><SELECT NAME="typenum" SIZE=1>
END

foreach $agent_type (qsearch('agent_type',{})) {
  print "<OPTION VALUE=". $agent_type->typenum;
  print " SELECTED"
    if $hashref->{typenum} && ( $hashref->{typenum} == $agent_type->typenum );
  print ">", $agent_type->getfield('typenum'), ": ",
        $agent_type->getfield('atype'),"\n";
}

print <<END;
</SELECT></TD>
</TR>
<TR>
  <TD ALIGN="right">Frequency (unimplemented)</TD>
  <TD><INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}"></TD>
</TR>
<TR>
  <TD ALIGN="right">Program (unimplemented)</TD>
  <TD><INPUT TYPE="text" NAME="prog" VALUE="$hashref->{prog}"></TD>
</TR>
</TABLE>
END

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{agentnum} ? "Apply changes" : "Add agent",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
