<%
#<!-- $Id: cust_main_county-expand.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $taxnum $cust_main_county $p1 $delim $expansion );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl);
use FS::cust_main_county;

$cgi = new CGI;

&cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $taxnum = $cgi->param('taxnum');
  $delim = $cgi->param('delim');
  $expansion = $cgi->param('expansion');
} else {
  my ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/
    or die "Illegal taxnum!";
  $taxnum = $1;
  $delim = 'n';
  $expansion = '';
}

$cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum});
die "Can't expand entry!" if $cust_main_county->getfield('county');

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Tax Rate (expand)", menubar(
  'Main Menu' => popurl(2),
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END;
    <FORM ACTION="${p1}process/cust_main_county-expand.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="taxnum" VALUE="$taxnum">
      Separate by
END
print '<INPUT TYPE="radio" NAME="delim" VALUE="n"';
print ' CHECKED' if $delim eq 'n';
print '>line (rumor has it broken on some browsers) or',
      '<INPUT TYPE="radio" NAME="delim" VALUE="s"';
print ' CHECKED' if $delim eq 's';
print '>whitespace.';
print <<END;
      <BR><INPUT TYPE="submit" VALUE="Submit">
      <BR><TEXTAREA NAME="expansion" ROWS=100>$expansion</TEXTAREA>
    </FORM>
    </CENTER>
  </BODY>
</HTML>
END

%>
