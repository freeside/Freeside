<%
#
# $Id: cust_main_county.cgi,v 1.2 2001-08-17 11:05:31 ivan Exp $
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
# Revision 1.2  2001-08-17 11:05:31  ivan
# clean up tax rate editing:
#   sort by country->state->county,
#   add "collapse state" if the tax rates are the same statewide,
#   redirect "expand state" to the browse, not edit screen
#
# Revision 1.1  2001/07/30 07:36:04  ivan
# templates!!!
#
# Revision 1.8  1999/04/09 04:22:34  ivan
# also table()
#
# Revision 1.7  1999/04/09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.6  1999/01/25 12:09:55  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:36  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:26  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 06:17:02  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/18 09:01:39  ivan
# i18n! i18n!
#

use strict;
use vars qw( $cgi $cust_main_county );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::cust_main_county;

$cgi = new CGI;

&cgisuidsetup($cgi);

print $cgi->header( '-expires' => 'now' ), header("Edit tax rates", menubar(
  'Main Menu' => popurl(2),
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="!, popurl(1),
    qq!process/cust_main_county.cgi" METHOD=POST>!, &table(), <<END;
      <TR>
        <TH><FONT SIZE=-1>Country</FONT></TH>
        <TH><FONT SIZE=-1>State</FONT></TH>
        <TH>County</TH>
        <TH><FONT SIZE=-1>Tax</FONT></TH>
      </TR>
END

foreach $cust_main_county ( sort {    $a->country cmp $b->country
                                   or $a->state   cmp $b->state
                                   or $a->county  cmp $b->county
                                 } qsearch('cust_main_county',{}) ) {
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

%>
