#!/usr/bin/perl -Tw
#
# process/cust_pay.cgi: Add a payment (process form)
#
# Usage: post form to:
#        http://server.name/path/cust_pay.cgi
#
# Note: Should be run setuid root as user nobody.
#
# ivan@voicenet.com 96-dec-11
#
# rewrite ivan@sisd.com 98-mar-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use FS::UID qw(cgisuidsetup);
use FS::cust_pay qw(fields);

my($req)=new CGI::Request;
&cgisuidsetup($req->cgi);

$req->param('invnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($invnum)=$1;

my($new) = create FS::cust_pay ( {
  map {
    $_, $req->param($_);
  } qw(invnum paid _date payby payinfo paybatch)
} );

my($error);
$error=$new->insert;

if ($error) { #error!
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error posting payment</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error posting payment</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and press the <I>Post</I> button again.
  </BODY>
</HTML>
END
} else { #no errors!
  $req->cgi->redirect("../../view/cust_bill.cgi?$invnum");
}

