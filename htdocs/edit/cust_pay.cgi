#!/usr/bin/perl -Tw
#
# $Id: cust_pay.cgi,v 1.3 1999-01-18 09:41:27 ivan Exp $
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
#
# $Log: cust_pay.cgi,v $
# Revision 1.3  1999-01-18 09:41:27  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.2  1998/12/17 06:17:03  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);

my($cgi) = new CGI;
cgisuidsetup($cgi);

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my($invnum)=$1;

my $p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Enter payment", ''), <<END;
    <FORM ACTION="${p1}process/cust_pay.cgi" METHOD=POST>
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

