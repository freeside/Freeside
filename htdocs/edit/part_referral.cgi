#!/usr/bin/perl -Tw
#
# $Id: part_referral.cgi,v 1.3 1999-01-18 09:41:30 ivan Exp $
#
# ivan@sisd.com 98-feb-23
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# confisuing typo on submit button ivan@sisd.com 98-jun-14
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_referral.cgi,v $
# Revision 1.3  1999-01-18 09:41:30  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.2  1998/12/17 06:17:06  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::part_referral;
use FS::CGI qw(header menubar);

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my($part_referral,$action);
if ( $cgi->var('QUERY_STRING') =~ /^(\d+)$/ ) { #editing
  $part_referral=qsearchs('part_referral',{'refnum'=>$1});
  $action='Edit';
} else { #adding
  $part_referral=create FS::part_referral {};
  $action='Add';
}
my($hashref)=$part_referral->hashref;

my $p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("$action Referral", menubar(
  'Main Menu' => popurl(2),
  'View all referrals' => popurl(2). "browse/part_referral.cgi",
)), <<END;
    <FORM ACTION="${p1}process/part_referral.cgi" METHOD=POST>
END

#display

print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$hashref->{refnum}">!,
      "Referral #", $hashref->{refnum} ? $hashref->{refnum} : "(NEW)";

print <<END;
<PRE>
Referral   <INPUT TYPE="text" NAME="referral" SIZE=32 VALUE="$hashref->{referral}">
</PRE>
END

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{refnum} ? "Apply changes" : "Add referral",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

