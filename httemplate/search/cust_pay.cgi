<%
#<!-- $Id: cust_pay.cgi,v 1.1 2001-12-26 09:18:18 ivan Exp $ -->

use strict;
use vars qw( $cgi $sortby @cust_pay );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl header menubar idiot table );
use FS::Record qw(qsearch );
use FS::cust_pay;
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('payinfo') =~ /^\s*(\d+)\s*$/ or die "illegal payinfo";
my $payinfo = $1;
$cgi->param('payby') =~ /^(\w+)$/ or die "illegal payby";
my $payby = $1;
@cust_pay = qsearch('cust_pay', { 'payinfo' => $payinfo,
                                  'payby'   => $payby    } );
$sortby = \*date_sort;

if (0) {
#if ( scalar(@cust_pay) == 1 ) {
#  my $invnum = $cust_bill[0]->invnum;
#  print $cgi->redirect(popurl(2). "view/cust_bill.cgi?$invnum");  #redirect
} elsif ( scalar(@cust_pay) == 0 ) {
  idiot("Check # not found.");
  #exit;
} else {
  my $total = scalar(@cust_pay);
  my $s = $total > 1 ? 's' : '';
  print header("Check # Search Results", menubar(
          'Main Menu', popurl(2)
        )), "$total matching check$s found<BR>", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>Amount</TH>
        <TH>Date</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  my(%saw, $cust_pay);
  foreach my $cust_pay (
    sort $sortby grep(!$saw{$_->paynum}++, @cust_pay)
  ) {
    my($paynum, $custnum, $payinfo, $amount, $date ) = (
      $cust_pay->paynum,
      $cust_pay->custnum,
      $cust_pay->payinfo,
      sprintf("%.2f", $cust_pay->paid),
      $cust_pay->_date,
    );
    my $pdate = time2str("%b %d %Y", $date);

    my $rowspan = 1;

    my $view = popurl(2). "view/cust_main.cgi?". $custnum. 
               "#". $payby. $payinfo;

    print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$payinfo</FONT></A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view"><FONT SIZE=-1>\$$amount</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$pdate</FONT></A></TD>
END
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
    if ( $cust_main ) {
      #my $cview = popurl(2). "view/cust_main.cgi?". $cust_main->custnum;
      my ( $name, $company ) = (
        $cust_main->last. ', '. $cust_main->first,
        $cust_main->company,
      );
      print <<END;
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$name</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$company</FONT></A></TD>
END
    } else {
      print <<END
        <TD ROWSPAN=$rowspan COLSPAN=2>WARNING: couldn't find cust_main.custnum $custnum (cust_pay.paynum $paynum)</TD>
END
    }

    print "</TR>";
  }
  print <<END;
    </TABLE>
  </BODY>
</HTML>
END

}

#

#sub invnum_sort {
#  $a->invnum <=> $b->invnum;
#}
#
#sub custnum_sort {
#  $a->custnum <=> $b->custnum || $a->invnum <=> $b->invnum;
#}

sub date_sort {
  $a->_date <=> $b->_date || $a->invnum <=> $b->invnum;
}
%>
