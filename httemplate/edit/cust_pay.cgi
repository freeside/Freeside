<%
#<!-- $Id: cust_pay.cgi,v 1.4 2001-10-26 10:24:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $link $linknum $p1 $_date $payby $payinfo $paid );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $link = $cgi->param('link');
  $linknum = $cgi->param('linknum');
  $paid = $cgi->param('paid');
  $payby = $cgi->param('payby');
  $payinfo = $cgi->param('payinfo');
} elsif ($cgi->keywords) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $link = 'invnum';
  $linknum = $1;
  $paid = '';
  $payby = 'BILL';
  $payinfo = "";
} elsif ( $cgi->param('custnum')  =~ /^(\d+)$/ ) {
  $link = 'custnum';
  $linknum = $1;
  $paid = '';
  $payby = 'BILL';
  $payinfo = '';
} else {
  die "illegal query ". $cgi->keywords;
}
$_date = time;

$p1 = popurl(1);
print $cgi->header( @FS::CGI::header ), header("Enter payment", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END;
    <FORM ACTION="${p1}process/cust_pay.cgi" METHOD=POST>
    <INPUT TYPE="hidden" NAME="link" VALUE="$link">
    <INPUT TYPE="hidden" NAME="linknum" VALUE="$linknum">
END

if ( $link eq 'invnum' ) {
  print "Invoice #<B>$linknum</B>";
} elsif ( $link eq 'custnum' ) {
  print "Customer #<B>$linknum</B>";
}

print qq!<BR>Date: <B>!, time2str("%D",$_date), qq!</B><INPUT TYPE="hidden" NAME="_date" VALUE="$_date">!;

print qq!<BR>Amount \$<INPUT TYPE="text" NAME="paid" VALUE="$paid" SIZE=8 MAXLENGTH=8>!;

print qq!<BR>Payby: <B>$payby</B><INPUT TYPE="hidden" NAME="payby" VALUE="$payby">!;

#payinfo (check # now as payby="BILL" hardcoded.. what to do later?)
print qq!<BR>Check #<INPUT TYPE="text" NAME="payinfo" VALUE="$payinfo">!;

#paybatch
print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

print <<END;
</PRE>
<BR>
<INPUT TYPE="submit" VALUE="Post payment">
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

%>
