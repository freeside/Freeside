<%
#<!-- $Id: part_referral.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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

%>
