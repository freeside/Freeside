#!/usr/bin/perl -Tw
#
# cust_pay.cgi: Add a payment (output form)
#
# Usage: cust_pay.cgi invnum
#        http://server.name/path/cust_pay.cgi?invnum
#
# Note: Should be run setuid as user nobody.
#
# some hooks for modifications as well as additions, but needs work.
#
# ivan@voicenet.com 96-dec-11
#
# rewrite ivan@sisd.com 98-mar-16

use strict;
use Date::Format;
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup);

my($cgi) = new CGI::Base;
$cgi->get;
cgisuidsetup($cgi);

#untaint invnum
$QUERY_STRING =~ /^(\d+)$/;
my($invnum)=$1;

SendHeaders(); # one guess.
print <<END;
<HTML>
  <HEAD>
    <TITLE>Enter payment</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Enter payment</H1>
    </CENTER>
    <FORM ACTION="process/cust_pay.cgi" METHOD=POST>
    <HR><PRE>
END

#invnum
print qq!Invoice #<B>$invnum</B><INPUT TYPE="hidden" NAME="invnum" VALUE="$invnum">!;

#date
my($date)=time;
print qq!<BR>Date: <B>!, time2str("%D",$date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="$date">!;

#paid
print qq!<BR>Amount \$<INPUT TYPE="text" NAME="paid" VALUE="" SIZE=8 MAXLENGTH=8>!;

#payby
my($payby)="BILL";
print qq!<BR>Payby: <B>$payby</B><INPUT TYPE="hidden" NAME="payby" VALUE="$payby">!;

#payinfo (check # now as payby="BILL" hardcoded.. what to do later?)
my($payinfo)="";
print qq!<BR>Check #<INPUT TYPE="text" NAME="payinfo" VALUE="$payinfo">!;

#paybatch
print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

print <<END;
</PRE>
<BR>
<CENTER><INPUT TYPE="submit" VALUE="Post"></CENTER>
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

