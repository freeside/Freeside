#!/usr/bin/perl -Tw
#
# $Id: agent.cgi,v 1.3 1998-12-17 08:40:16 ivan Exp $
#
# ivan@sisd.com 97-dec-12
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: agent.cgi,v $
# Revision 1.3  1998-12-17 08:40:16  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/23 07:52:29  ivan
# *** empty log message ***
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::agent qw(fields);
use FS::CGI qw(idiot popurl);

my($cgi)=new CGI;

&cgisuidsetup($cgi);

my($agentnum)=$cgi->param('agentnum');

my($old)=qsearchs('agent',{'agentnum'=>$agentnum}) if $agentnum;

#unmunge typenum
$cgi->param('typenum') =~ /^(\d+)(:.*)?$/;
$cgi->param('typenum',$1);

my($new)=create FS::agent ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent')
} );

my($error);
if ( $agentnum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $agentnum=$new->getfield('agentnum');
}

if ( $error ) {
  &idiot($error);
} else { 
  print $cgi->redirect(popurl(3). "browse/agent.cgi");
}

