#!/usr/bin/perl -Tw
#
# process/cust_credit.cgi: Add a credit (process form)
#
# Usage: post form to:
#        http://server.name/path/cust_credit.cgi
#
# Note: Should be run setuid root as user nobody.
#
# ivan@voicenet.com 96-dec-05 -> 96-dec-08
#
# post a refund if $new_paybatch
# ivan@voicenet.com 96-dec-08
#
# refunds are no longer applied against a specific payment (paybatch)
# paybatch field removed
# ivan@voicenet.com 97-apr-22
#
# rewrite ivan@sisd.com 98-mar-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use FS::UID qw(cgisuidsetup getotaker);
use FS::cust_credit;

my($req)=new CGI::Request; # create form object
cgisuidsetup($req->cgi);

$req->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
my($custnum)=$1;

$req->param('otaker',getotaker);

my($new) = create FS::cust_credit ( {
  map {
    $_, $req->param($_);
  } qw(custnum _date amount otaker reason)
} );

my($error);
$error=$new->insert;
&idiot($error) if $error;

#no errors, no refund, so view our credit.
$req->cgi->redirect("../../view/cust_main.cgi?$custnum#history");

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error posting credit/refund</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error posting credit/refund</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and press the <I>Post</I> button again.
  </BODY>
</HTML>
END

}

