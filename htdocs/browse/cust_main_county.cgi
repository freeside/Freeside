#!/usr/bin/perl -Tw
#
# $Id: cust_main_county.cgi,v 1.4 1999-01-18 09:41:16 ivan Exp $
#
# ivan@sisd.com 97-dec-13
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: cust_main_county.cgi,v $
# Revision 1.4  1999-01-18 09:41:16  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 05:25:18  ivan
# fix visual and other bugs
#
# Revision 1.2  1998/11/18 09:01:34  ivan
# i18n! i18n!
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::cust_main_county;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my($p) = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("Tax Rate Listing", menubar(
  'Main Menu' => $p,
  'Edit tax rates' => $p. "edit/cust_main_county.cgi",
)),<<END;
    Click on <u>expand country</u> to specify a country's tax rates by state.
    <BR>Click on <u>expand state</u> to specify a state's tax rates by county.
    <BR><BR>
END
print table, <<END;
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
      : qq!(ALL) <FONT SIZE=-1>!.
        qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
        qq!">expand country</A></FONT>!
    , "</TD>";
  print "<TD>";
  if ( $hashref->{county} ) {
    print $hashref->{county};
  } else {
    print "(ALL)";
    if ( $hashref->{state} ) {
      print qq!<FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand state</A></FONT>!;
    }
  }
  print "</TD>";

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

