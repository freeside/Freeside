#!/usr/bin/perl -Tw
#
# process/agent.cgi: Edit agent (process form)
#
# ivan@sisd.com 97-dec-12
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::agent qw(fields);
use FS::CGI qw(idiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

my($agentnum)=$req->param('agentnum');

my($old)=qsearchs('agent',{'agentnum'=>$agentnum}) if $agentnum;

#unmunge typenum
$req->param('typenum') =~ /^(\d+)(:.*)?$/;
$req->param('typenum',$1);

my($new)=create FS::agent ( {
  map {
    $_, $req->param($_);
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
  #$req->cgi->redirect("../../view/agent.cgi?$agentnum");
  #$req->cgi->redirect("../../edit/agent.cgi?$agentnum");
  $req->cgi->redirect("../../browse/agent.cgi");
}

