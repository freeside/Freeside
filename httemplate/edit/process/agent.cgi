<%
#<!-- $Id: agent.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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
