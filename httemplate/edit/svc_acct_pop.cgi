<%
#
# $Id: svc_acct_pop.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@sisd.com 98-mar-8 
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: svc_acct_pop.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.9  2000/01/28 23:02:48  ivan
# track full phone number
#
# Revision 1.8  1999/02/23 08:09:23  ivan
# beginnings of one-screen new customer entry and some other miscellania
#
# Revision 1.7  1999/02/07 09:59:23  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.6  1999/01/19 05:13:44  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 09:41:33  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/23 02:57:45  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.3  1998/12/17 06:17:10  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/13 09:56:47  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use vars qw( $cgi $svc_acct_pop $action $query $hashref $p1 );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::CGI qw(header menubar popurl);
use FS::svc_acct_pop;
$cgi = new CGI;
&cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $svc_acct_pop = new FS::svc_acct_pop ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct_pop')
  } );
} elsif ( $cgi->keywords ) { #editing
  my($query)=$cgi->keywords;
  $query =~ /^(\d+)$/;
  $svc_acct_pop=qsearchs('svc_acct_pop',{'popnum'=>$1});
} else { #adding
  $svc_acct_pop = new FS::svc_acct_pop {};
}
$action = $svc_acct_pop->popnum ? 'Edit' : 'Add';
$hashref = $svc_acct_pop->hashref;

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("$action POP", menubar(
  'Main Menu' => popurl(2),
  'View all POPs' => popurl(2). "browse/svc_acct_pop.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/svc_acct_pop.cgi" METHOD=POST>!;

#display

print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$hashref->{popnum}">!,
      "POP #", $hashref->{popnum} ? $hashref->{popnum} : "(NEW)";

print <<END;
<PRE>
City      <INPUT TYPE="text" NAME="city" SIZE=32 VALUE="$hashref->{city}">
State     <INPUT TYPE="text" NAME="state" SIZE=16 MAXLENGTH=16 VALUE="$hashref->{state}">
Area Code <INPUT TYPE="text" NAME="ac" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{ac}">
Exchange  <INPUT TYPE="text" NAME="exch" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{exch}">
Local     <INPUT TYPE="text" NAME="loc" SIZE=5 MAXLENGTH=4 VALUE="$hashref->{loc}">
</PRE>
END

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{popnum} ? "Apply changes" : "Add POP",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
