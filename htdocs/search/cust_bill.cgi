#!/usr/bin/perl -Tw
#
# cust_bill.cgi: Search for invoices (process form)
#
# Usage: post form to:
#        http://server.name/path/cust_bill.cgi
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 97-apr-4
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);

my($req)=new CGI::Request;
cgisuidsetup($req->cgi);

$req->param('invnum') =~ /^\s*(FS-)?(\d+)\s*$/;
my($invnum)=$2;

if ( qsearchs('cust_bill',{'invnum'=>$invnum}) ) {
  $req->cgi->redirect("../view/cust_bill.cgi?$invnum");  #redirect
} else { #error
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Invoice Search Error</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H3>Invoice Search Error</H3>
    <HR>
    Invoice not found.
    </CENTER>
  </BODY>
</HTML>
END

}

