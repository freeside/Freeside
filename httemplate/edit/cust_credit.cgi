<%
#<!-- $Id: cust_credit.cgi,v 1.3 2001-09-03 22:07:39 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $custnum $otaker $p1 $crednum $_date $amount $reason );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(fields);
#use FS::cust_credit;

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  #$cust_credit = new FS::cust_credit ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit')
  #} );
  $custnum = $cgi->param('custnum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $reason = $cgi->param('reason');
} else {
  ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum = $1;
  $amount = '';
  #$refund = 'yes';
  $reason = '';
}
$_date = time;

$otaker = getotaker;

$p1 = popurl(1);

print $cgi->header( '-expires' => 'now' ), header("Post Credit", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print <<END;
    <FORM ACTION="${p1}process/cust_credit.cgi" METHOD=POST>
END

$crednum = "";
print qq!Credit #<B>!, $crednum ? $crednum : " <I>(NEW)</I>", qq!</B><INPUT TYPE="hidden" NAME="crednum" VALUE="$crednum">!;

print qq!<BR>Customer #<B>$custnum</B><INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!;

print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

print qq!<BR>Date: <B>!, time2str("%D",$_date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="">!;

print qq!<BR>Amount \$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8>!;
print qq!<INPUT TYPE="hidden" NAME="credited" VALUE="">!;

#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="$refund">Also post refund!;

print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!;

print qq!<BR>Reason <INPUT TYPE="text" NAME="reason" VALUE="$reason">!;

print <<END;
<BR>
<INPUT TYPE="submit" VALUE="Post">
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

%>
