#!/usr/bin/perl -Tw
#
# svc_acct_pop.cgi: Add/Edit pop (output form)
#
# ivan@sisd.com 98-mar-8 
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::svc_acct_pop;
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

my($svc_acct_pop,$action);
if ( $cgi->var('QUERY_STRING') =~ /^(\d+)$/ ) { #editing
  $svc_acct_pop=qsearchs('svc_acct_pop',{'popnum'=>$1});
  $action='Edit';
} else { #adding
  $svc_acct_pop=create FS::svc_acct_pop {};
  $action='Add';
}
my($hashref)=$svc_acct_pop->hashref;

print header("$action POP", menubar(
  'Main Menu' => '../',
  'View all POPs' => "../browse/svc_acct_pop.cgi",
)), <<END;
    <FORM ACTION="process/svc_acct_pop.cgi" METHOD=POST>
END

#display

print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$hashref->{popnum}">!,
      "POP #", $hashref->{popnum} ? $hashref->{popnum} : "(NEW)";

print <<END;
<PRE>
City      <INPUT TYPE="text" NAME="city" SIZE=32 VALUE="$hashref->{city}">
State     <INPUT TYPE="text" NAME="state" SIZE=3 MAXLENGTH=2 VALUE="$hashref->{state}">
Area Code <INPUT TYPE="text" NAME="ac" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{ac}">
Exchange  <INPUT TYPE="text" NAME="exch" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{exch}">
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

