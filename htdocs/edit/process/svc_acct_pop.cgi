#!/usr/bin/perl -Tw
#
# process/svc_acct_pop.cgi: Edit POP (process form)
#
# ivan@sisd.com 98-mar-8
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
use FS::svc_acct_pop qw(fields);
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

my($popnum)=$req->param('popnum');

my($old)=qsearchs('svc_acct_pop',{'popnum'=>$popnum}) if $popnum;

my($new)=create FS::svc_acct_pop ( {
  map {
    $_, $req->param($_);
  } fields('svc_acct_pop')
} );

if ( $popnum ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $popnum=$new->getfield('popnum');
}
$req->cgi->redirect("../../browse/svc_acct_pop.cgi");

