#!/usr/bin/perl -Tw
#
# process/part_referral.cgi: Edit referrals (process form)
#
# ivan@sisd.com 98-feb-23
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
use FS::part_referral qw(fields);
use FS::CGI qw(eidiot);
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

my($refnum)=$req->param('refnum');

my($new)=create FS::part_referral ( {
  map {
    $_, $req->param($_);
  } fields('part_referral')
} );

if ( $refnum ) {
  my($old)=qsearchs('part_referral',{'refnum'=>$refnum});
  eidiot("(Old) Record not found!") unless $old;
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
}

$refnum=$new->getfield('refnum');
$req->cgi->redirect("../../browse/part_referral.cgi");

