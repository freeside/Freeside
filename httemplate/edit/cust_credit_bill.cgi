<%
#<!-- $Id: cust_credit_bill.cgi,v 1.1 2001-09-01 21:52:20 jeff Exp $ -->

use strict;
use vars qw( $cgi $query $custnum $invnum $otaker $p1 $crednum $_date $amount $reason $cust_credit );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch fields);
use FS::cust_credit;
use FS::cust_bill;


$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  #$cust_credit_bill = new FS::cust_credit_bill ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit_bill')
  #} );
  $crednum = $cgi->param('crednum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $invnum = $cgi->param('invnum');
} else {
  ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $crednum = $1;
  $amount = '';
  #$refund = 'yes';
  $invnum = '';
}
$_date = time;

$otaker = getotaker;

$p1 = popurl(1);

print $cgi->header( '-expires' => 'now' ), header("Apply Credit", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print <<END;
    <FORM ACTION="${p1}process/cust_credit_bill.cgi" METHOD=POST>
    <PRE>
END

die unless $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } );

print qq!Credit #<B>!, $crednum, qq!</B><INPUT TYPE="hidden" NAME="crednum" VALUE="$crednum">!;

print qq!\nInvoice # <SELECT NAME="invnum" SIZE=1>!;
foreach $_ (grep $_->owed, qsearch('cust_bill', { 'custnum' => $cust_credit->custnum } ) ) {
  print "<OPTION", (($_->invnum eq $invnum) ? " SELECTED" : ""),
    qq! VALUE="! .$_->invnum. qq!">!. $_->invnum. qq! (! . $_->owed . qq!)!;
}
print qq!<OPTION VALUE="Refund">Refund!;
print "</SELECT>";

print qq!\nDate: <B>!, time2str("%D",$_date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="">!;

print qq!\nAmount \$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8>!;

#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="$refund">Also post refund!;

print <<END;
</PRE>
<BR>
<CENTER><INPUT TYPE="submit" VALUE="Post"></CENTER>
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

%>
