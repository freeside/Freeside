<%
#
# $Id: agent.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@sisd.com 97-dec-12
#
# Changes to allow page to work at a relative position in server
# Changed 'type' to 'atype' because Pg6.3 reserves the type word
#	bmccane@maxbaud.net	98-apr-3
#
# use FS::CGI, added inline documentation ivan@sisd.com 98-jul-12
#
# $Log: agent.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.7  1999/04/07 11:27:50  ivan
# avoid perl's silly arguement not numeric error
#
# Revision 1.6  1999/01/25 12:09:50  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:31  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:21  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 06:16:57  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/23 07:52:08  ivan
# *** empty log message ***
#

use strict;
use vars qw ( $cgi $agent $action $hashref $p $agent_type );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl);
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

print <<END;
<PRE>
Agent                     <INPUT TYPE="text" NAME="agent" SIZE=32 VALUE="$hashref->{agent}">
Agent type                <SELECT NAME="typenum" SIZE=1>
END

foreach $agent_type (qsearch('agent_type',{})) {
  print "<OPTION VALUE=". $agent_type->typenum;
  print " SELECTED"
    if $hashref->{typenum} && ( $hashref->{typenum} == $agent_type->typenum );
  print ">", $agent_type->getfield('typenum'), ": ",
        $agent_type->getfield('atype'),"\n";
}

print <<END;
</SELECT>
Frequency (unimplemented) <INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}">
Program (unimplemented)   <INPUT TYPE="text" NAME="prog" VALUE="$hashref->{prog}">
</PRE>
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
