#!/usr/bin/perl -Tw
#
# $Id: part_referral.cgi,v 1.6 1999-04-07 11:43:23 ivan Exp $
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
# Revision 1.6  1999-04-07 11:43:23  ivan
# pick up errors right away, leave input
#
# Revision 1.5  1999/02/07 09:59:20  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:13:41  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1999/01/18 09:41:30  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.2  1998/12/17 06:17:06  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use vars qw( $cgi $part_referral $action $hashref $p1 $query );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::part_referral;
use FS::CGI qw(header menubar popurl);

$cgi = new CGI;

&cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $part_referral = new FS::part_referral ( {
    map { $_, scalar($cgi->param($_)) } fields('part_referral')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $part_referral = qsearchs( 'part_referral', { 'refnum' => $1 } );
} else { #adding
  $part_referral = new FS::part_referral {};
}
$action = $part_referral->refnum ? 'Edit' : 'Add';
$hashref = $part_referral->hashref;

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("$action Referral", menubar(
  'Main Menu' => popurl(2),
  'View all referrals' => popurl(2). "browse/part_referral.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/part_referral.cgi" METHOD=POST>!;

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

