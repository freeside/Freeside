<%
#
# $Id: cust_main_county-expand.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: cust_main_county-expand.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.6  1999/01/25 12:09:54  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:35  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:25  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 06:17:01  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/18 09:01:38  ivan
# i18n! i18n!
#

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
