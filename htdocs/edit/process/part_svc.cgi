#!/usr/bin/perl -Tw
#
# process/part_svc.cgi: Edit service definitions (process form)
#
# ivan@sisd.com 97-nov-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::part_svc qw(fields);
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

my($svcpart)=$req->param('svcpart');

my($old)=qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

my($new)=create FS::part_svc ( {
  map {
    $_, $req->param($_);
#  } qw(svcpart svc svcdb)
  } fields('part_svc')
} );

if ( $svcpart ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $svcpart=$new->getfield('svcpart');
}

#$req->cgi->redirect("../../view/part_svc.cgi?$svcpart");
#$req->cgi->redirect("../../edit/part_svc.cgi?$svcpart");
$req->cgi->redirect("../../browse/part_svc.cgi");

