#!/usr/bin/perl -Tw
#
# $Id: cust_credit.cgi,v 1.7 1999-02-28 00:03:33 ivan Exp $
#
# Usage: cust_credit.cgi custnum [ -paybatch ]
#        http://server.name/path/cust_credit?custnum [ -paybatch ]
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
# Revision 1.7  1999-02-28 00:03:33  ivan
# removed misleading comments
#
# Revision 1.6  1999/01/25 12:09:52  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:33  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:23  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/23 02:26:06  ivan
# *** empty log message ***
#
# Revision 1.2  1998/12/17 06:16:59  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use vars qw( $cgi $query $custnum $otaker $p1 $crednum $_date $amount $reason );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(fields);
#use FS::cust_credit;

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  #$cust_credit = new FS::cust_credit ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit')
  #} );
  $custnum = $cgi->param('custnum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $reason = $cgi->param('reason');
} else {
  ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum = $1;
  $amount = '';
  #$refund = 'yes';
  $reason = '';
}
$_date = time;

$otaker = getotaker;

$p1 = popurl(1);

print $cgi->header( '-expires' => 'now' ), header("Post Credit", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print <<END;
    <FORM ACTION="${p1}process/cust_credit.cgi" METHOD=POST>
    <PRE>
END

$crednum = "";
print qq!Credit #<B>!, $crednum ? $crednum : " <I>(NEW)</I>", qq!</B><INPUT TYPE="hidden" NAME="crednum" VALUE="$crednum">!;

print qq!\nCustomer #<B>$custnum</B><INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!;

print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

print qq!\nDate: <B>!, time2str("%D",$_date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="">!;

print qq!\nAmount \$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8>!;
print qq!<INPUT TYPE="hidden" NAME="credited" VALUE="">!;

#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="$refund">Also post refund!;

print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!;

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

