#!/usr/bin/perl -Tw
#
# svc_acct_pop.cgi: browse pops 
#
# ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.
print header('POP Listing', menubar(
  'Main Menu' => '../',
  'Add new POP' => "../edit/svc_acct_pop.cgi",
)), <<END;
    <BR>Click on pop number to edit.
    <TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>POP #</FONT></TH>
        <TH>City</TH>
        <TH>State</TH>
        <TH>Area code</TH>
        <TH>Exchange</TH>
      </TR>
END

my($svc_acct_pop);
foreach $svc_acct_pop ( sort { 
  $a->getfield('popnum') <=> $b->getfield('popnum')
} qsearch('svc_acct_pop',{}) ) {
  my($hashref)=$svc_acct_pop->hashref;
  print <<END;
      <TR>
        <TD><A HREF="../edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{popnum}</A></TD>
        <TD>$hashref->{city}</TD>
        <TD>$hashref->{state}</TD>
        <TD>$hashref->{ac}</TD>
        <TD>$hashref->{exch}</TD>
      </TR>
END

}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

