#!/usr/bin/perl -Tw
#
# cust_main_county.cgi: Edit tax rates (output form)
#
# ivan@sisd.com 97-dec-13-16
#
# Changes to allow page to work at a relative position in server
# Changed tax field to accept 6 chars (MO uses 6.1%)
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

print header("Edit tax rates", menubar(
  'Main Menu' => '../',
)),<<END;
    <FORM ACTION="process/cust_main_county.cgi" METHOD=POST>
    <TABLE BORDER>
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
      : '(ALL)'
    , "</TD>";

  print qq!<TD><INPUT TYPE="text" NAME="tax!, $hashref->{taxnum},
        qq!" VALUE="!, $hashref->{tax}, qq!" SIZE=6 MAXLENGTH=6>%</TD></TR>!;
END

}

print <<END;
    </TABLE>
    <INPUT TYPE="submit" VALUE="Apply changes">
    </FORM>
    </CENTER>
  </BODY>
</HTML>
END

