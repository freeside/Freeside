#!/usr/bin/perl -Tw
#
# agent.cgi: Add/Edit agent (output form)
#
# ivan@sisd.com 97-dec-12
#
# Changes to allow page to work at a relative position in server
# Changed 'type' to 'atype' because Pg6.3 reserves the type word
#	bmccane@maxbaud.net	98-apr-3
#
# use FS::CGI, added inline documentation ivan@sisd.com 98-jul-12

use strict;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::agent;
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

my($agent,$action);
if ( $cgi->var('QUERY_STRING') =~ /^(\d+)$/ ) { #editing
  $agent=qsearchs('agent',{'agentnum'=>$1});
  $action='Edit';
} else { #adding
  $agent=create FS::agent {};
  $action='Add';
}
my($hashref)=$agent->hashref;

print header("$action Agent", menubar(
  'Main Menu' => '../',
  'View all agents' => '../browse/agent.cgi',
)), '<FORM ACTION="process/agent.cgi" METHOD=POST>';

print qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$hashref->{agentnum}">!,
      "Agent #", $hashref->{agentnum} ? $hashref->{agentnum} : "(NEW)";

print <<END;
<PRE>
Agent                     <INPUT TYPE="text" NAME="agent" SIZE=32 VALUE="$hashref->{agent}">
Agent type                <SELECT NAME="typenum" SIZE=1>
END

my($agent_type);
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

