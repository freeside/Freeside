<%
#<!-- $Id: part_referral.cgi,v 1.3 2001-08-21 09:34:13 ivan Exp $ -->

use strict;
use vars qw( $cgi $p $part_referral );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch);
use FS::CGI qw(header menubar popurl table);
use FS::part_referral;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("Referral Listing", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)), "Where a customer heard about your service. Tracked for informational purposes.<BR><BR>", &table(), <<END;
      <TR>
        <TH COLSPAN=2>Referral</TH>
      </TR>
END

foreach $part_referral ( sort { 
  $a->getfield('refnum') <=> $b->getfield('refnum')
} qsearch('part_referral',{}) ) {
  my($hashref)=$part_referral->hashref;
  print <<END;
      <TR>
        <TD><A HREF="${p}edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{refnum}</A></TD>
        <TD><A HREF="${p}edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{referral}</A></TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="${p}edit/part_referral.cgi"><I>Add new referral</I></A></TD>
      </TR>
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

%>
