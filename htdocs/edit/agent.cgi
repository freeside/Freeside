#!/usr/bin/perl -Tw
#
# $Id: agent.cgi,v 1.5 1999-01-19 05:13:31 ivan Exp $
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
# Revision 1.5  1999-01-19 05:13:31  ivan
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
use vars qw ( $cgi $agent $action $query $hashref $p $agent_type );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl);
use FS::Record qw(qsearch qsearchs);
use FS::agent;
use FS::agent_type;

$cgi = new CGI;

&cgisuidsetup($cgi);

($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ ) { #editing
  $agent=qsearchs('agent',{'agentnum'=>$1});
  $action='Edit';
} else { #adding
  $agent = new FS::agent {};
  $action='Add';
}
$hashref = $agent->hashref;

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("$action Agent", menubar(
  'Main Menu' => $p,
  'View all agents' => $p. 'browse/agent.cgi',
)), '<FORM ACTION="', popurl(1), 'process/agent.cgi" METHOD=POST>';

print qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$hashref->{agentnum}">!,
      "Agent #", $hashref->{agentnum} ? $hashref->{agentnum} : "(NEW)";

print <<END;
<PRE>
Agent                     <INPUT TYPE="text" NAME="agent" SIZE=32 VALUE="$hashref->{agent}">
Agent type                <SELECT NAME="typenum" SIZE=1>
END

foreach $agent_type (qsearch('agent_type',{})) {
  print "<OPTION";
  print " SELECTED"
    if $hashref->{typenum} == $agent_type->getfield('typenum');
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

