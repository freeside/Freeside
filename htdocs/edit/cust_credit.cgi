#!/usr/bin/perl -Tw
#
# $Id: cust_credit.cgi,v 1.2 1998-12-17 06:16:59 ivan Exp $
#
# Usage: cust_credit.cgi custnum [ -paybatch ]
#        http://server.name/path/cust_credit?custnum [ -paybatch ]
#
# Note: Should be run setuid root as user nobody.
#
# some hooks in here for modifications as well as additions, but needs (lots) more work.
# also see process/cust_credit.cgi, the script that processes the form.
#
# ivan@voicenet.com 96-dec-05
#
# paybatch field, differentiates between credits & credits+refunds by commandline
# ivan@voicenet.com 96-dec-08
#
# added (but commented out) sprintf("%.2f" in amount field.  Hmm.
# ivan@voicenet.com 97-jan-3
#
# paybatch stuff thrown out - has checkbox now instead.  
# (well, sort of.  still passed around for backward compatability and possible editing hook)
# ivan@voicenet.com 97-apr-21
#
# rewrite ivan@sisd.com 98-mar-16
#
# $Log: cust_credit.cgi,v $
# Revision 1.2  1998-12-17 06:16:59  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker popurl);
use FS::CGI qw(header popurl);

my $cgi = new CGI;

cgisuidsetup($cgi);

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my($custnum)=$1;

my($otaker)=getotaker;

my $p1 = popurl(1);

print $cgi->header, header("Post Credit", ''), <<END;
    <FORM ACTION="${p1}process/cust_credit.cgi" METHOD=POST>
    <HR><PRE>
END

#crednum
my($crednum)="";
print qq!Credit #<B>!, $crednum ? $crednum : " <I>(NEW)</I>", qq!</B><INPUT TYPE="hidden" NAME="crednum" VALUE="$crednum">!;

#custnum
print qq!\nCustomer #<B>$custnum</B><INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!;

#paybatch
print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

#date
my($date)=time;
print qq!\nDate: <B>!, time2str("%D",$date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="$date">!;

#amount
my($amount)='';
print qq!\nAmount \$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8>!;

#refund?
#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="yes">Also post refund!;

#otaker (hidden)
print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!;

#reason
my($reason)='';
print qq!\nReason <INPUT TYPE="text" NAME="reason" VALUE="$reason" SIZE=72>!;

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

