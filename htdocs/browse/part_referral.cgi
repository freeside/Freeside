#!/usr/bin/perl -Tw
#
# $Id: part_referral.cgi,v 1.4 1998-12-17 04:32:55 ivan Exp $
#
# ivan@sisd.com 98-feb-23 
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_referral.cgi,v $
# Revision 1.4  1998-12-17 04:32:55  ivan
# print $cgi->header
#
# Revision 1.3  1998/12/17 04:31:36  ivan
# use CGI::Carp
#
# Revision 1.2  1998/12/17 04:26:04  ivan
# use CGI; no relative URLs
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch);
use FS::CGI qw(header menubar popurl table);

my $cgi = new CGI;

&cgisuidsetup($cgi);

print $cgi->header, header("Referral Listing", menubar(
  'Main Menu' => popurl(2),
#  'Add new referral' => "../edit/part_referral.cgi",
)), table, <<END;
      <TR>
        <TH COLSPAN=2>Referral</TH>
      </TR>
END

my($part_referral);
my($p)=popurl(2);
foreach $part_referral ( sort { 
  $a->getfield('refnum') <=> $b->getfield('refnum')
} qsearch('part_referral',{}) ) {
  my($hashref)=$part_referral->hashref;
  print <<END;
      <TR>
        <TD><A HREF="$p/edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{refnum}</A></TD>
        <TD><A HREF="$p/edit/part_referral.cgi?$hashref->{refnum}">
          $hashref->{referral}</A></TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="$p/edit/part_referral.cgi"><I>Add new referral</I></A></TD>
      </TR>
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

