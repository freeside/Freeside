<%
#
# $Id: agent.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@sisd.com 97-dec-12
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: agent.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.7  1999/01/25 12:09:57  ivan
# yet more mod_perl stuff
#
# Revision 1.6  1999/01/19 05:13:47  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 22:47:49  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.4  1998/12/30 23:03:26  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.3  1998/12/17 08:40:16  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/23 07:52:29  ivan
# *** empty log message ***
#

use strict;
use vars qw ( $cgi $agentnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::agent;
use FS::CGI qw(popurl);

$cgi = new CGI;

&cgisuidsetup($cgi);

$agentnum = $cgi->param('agentnum');

$old = qsearchs('agent',{'agentnum'=>$agentnum}) if $agentnum;

$new = new FS::agent ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent')
} );

if ( $agentnum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $agentnum=$new->getfield('agentnum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "agent.cgi?". $cgi->query_string );
} else { 
  print $cgi->redirect(popurl(3). "browse/agent.cgi");
}

%>
