#!/usr/bin/perl -Tw
#
# $Id: cust_main_county.cgi,v 1.2 1998-11-18 09:01:39 ivan Exp $
#
# ivan@sisd.com 97-dec-13-16
#
# Changes to allow page to work at a relative position in server
# Changed tax field to accept 6 chars (MO uses 6.1%)
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
# 
# $Log: cust_main_county.cgi,v $
# Revision 1.2  1998-11-18 09:01:39  ivan
# i18n! i18n!
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::cust_main_county;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

print $cgi->header, header("Edit tax rates", menubar(
  'Main Menu' => popurl(2),
)), qq!<FORM ACTION="!, popurl(1),
    qq!/process/cust_main_county.cgi" METHOD=POST>!, table, <<END;
      <TR>
        <TH><FONT SIZE=-1>Country</FONT></TH>
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
        <TD>$hashref->{country}</TD>
END

  print "<TD>", $hashref->{state}
      ? $hashref->{state}
      : '(ALL)'
    , "</TD>";

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

