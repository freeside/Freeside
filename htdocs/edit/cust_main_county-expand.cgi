#!/usr/bin/perl -Tw
#
# cust_main_county-expand.cgi: Expand a state into counties (output form)
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
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

$cgi->var('QUERY_STRING') =~ /^(\d+)$/
  or die "Illegal taxnum!";
my($taxnum)=$1;

my($cust_main_county)=qsearchs('cust_main_county',{'taxnum'=>$taxnum});
die "Can't expand entry!" if $cust_main_county->getfield('county');

print header("Tax Rate (expand state)", menubar(
  'Main Menu' => '../',
)), <<END;
    <FORM ACTION="process/cust_main_county-expand.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="taxnum" VALUE="$taxnum">
      Separate counties by
      <INPUT TYPE="radio" NAME="delim" VALUE="n" CHECKED>line
      (rumor has it broken on some browsers) or
      <INPUT TYPE="radio" NAME="delim" VALUE="s">whitespace.
      <BR><INPUT TYPE="submit" VALUE="Submit">
      <BR><TEXTAREA NAME="counties" ROWS=100></TEXTAREA>
    </FORM>
    </CENTER>
  </BODY>
</HTML>
END

