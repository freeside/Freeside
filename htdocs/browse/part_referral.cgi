#!/usr/bin/perl -Tw
#
# part_referral.cgi: Browse part_referral
#
# ivan@sisd.com 98-feb-23 
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.
print header("Referral Listing", menubar(
  'Main Menu' => '../',
  'Add new referral' => "../edit/part_referral.cgi",
)), <<END;
    <BR>Click on referral number to edit.
    <TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>Referral #</FONT></TH>
        <TH>Referral</TH>
      </TR>
END

my($part_referral);
foreach $part_referral ( sort { 
  $a->getfield('refnum') <=> $b->getfield('refnum')
} qsearch('part_referral',{}) ) {
  my($hashref)=$part_referral->hashref;
  print <<END;
      <TR>
        <TD><A HREF="../edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{refnum}</A></TD>
        <TD>$hashref->{referral}</TD>
      </TR>
END

}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

