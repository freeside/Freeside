#!/usr/bin/perl -Tw
#
# cust_main_county.cgi: browse cust_main_county
#
# ivan@sisd.com 97-dec-13
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
print header("Tax Rate Listing", menubar(
  'Main Menu' => '../',
  'Edit tax rates' => "../edit/cust_main_county.cgi",
)),<<END;
    <BR>Click on <u>expand</u> to specify tax rates by county.
    <P><TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>State</FONT></TH>
        <TH>County</TH>
        <TH><FONT SIZE=-1>Tax</FONT></TH>
      </TR>
END

my($cust_main_county);
foreach $cust_main_county ( qsearch('cust_main_county',{}) ) {
  my($hashref)=$cust_main_county->hashref;
  print <<END;
      <TR>
        <TD>$hashref->{state}</TD>
END

  print "<TD>", $hashref->{county}
      ? $hashref->{county}
      : qq!(ALL) <FONT SIZE=-1>!.
        qq!<A HREF="../edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
        qq!">expand</A></FONT>!
    , "</TD>";

  print <<END;
        <TD>$hashref->{tax}%</TD>
      </TR>
END

}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

