<%
#<!-- $Id: cust_main_county.cgi,v 1.5 2001-10-30 14:54:07 ivan Exp $ -->

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

print header("Edit tax rates", menubar(
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
