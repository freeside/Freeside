<%
#<!-- $Id: cust_pay.cgi,v 1.7 2001-12-26 02:33:30 ivan Exp $ -->

use strict;
use vars qw( $cgi $link $linknum $p1 $_date $payby $payinfo $paid );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::Conf;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl ntable);

my $conf = new FS::Conf;

my $countrydefault = $conf->config('countrydefault') || 'US';

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
print header("Enter payment", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END, ntable("#cccccc",2);
    <FORM ACTION="${p1}process/cust_pay.cgi" METHOD=POST>
    <INPUT TYPE="hidden" NAME="link" VALUE="$link">
    <INPUT TYPE="hidden" NAME="linknum" VALUE="$linknum">
END

my $custnum;
if ( $link eq 'invnum' ) {

  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $linknum } )
    or die "unknown invnum $linknum";
  print "Invoice #<B>$linknum</B>". ntable("#cccccc",2).
        '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
        time2str("%D", $cust_bill->_date). '</TD></TR>'.
        '<TR><TD ALIGN="right" VALIGN="top">Items</TD><TD BGCOLOR="#ffffff">';
  foreach ( $cust_bill->cust_bill_pkg ) { #false laziness with FS::cust_bill
    if ( $_->pkgnum ) {

      my($cust_pkg)=qsearchs('cust_pkg', { 'pkgnum', $_->pkgnum } );
      my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->pkgpart});
      my($pkg)=$part_pkg->pkg;

      if ( $_->setup != 0 ) {
        print "$pkg Setup<BR>"; # $money_char. sprintf("%10.2f",$_->setup);
        print join('<BR>',
          map { "  ". $_->[0]. ": ". $_->[1] } $cust_pkg->labels
        ). '<BR>';
      }

      if ( $_->recur != 0 ) {
        print
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")<BR>";
          #$money_char. sprintf("%10.2f",$_->recur)
        print join('<BR>',
          map { '--->'. $_->[0]. ": ". $_->[1] } $cust_pkg->labels
        ). '<BR>';
      }

    } else { #pkgnum Tax
      print "Tax<BR>" # $money_char. sprintf("%10.2f",$_->setup)
        if $_->setup != 0;
    }

  }
  print '</TD></TR></TABLE>';

  $custnum = $cust_bill->custnum;

} elsif ( $link eq 'custnum' ) {
  $custnum = $linknum;
}

print "<BR><BR>Customer #<B>$custnum</B>". ntable('#e8e8e8');
my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
  or die "unknown custnum $custnum";

print '<TR><TD>'. ntable("#cccccc",2).
      '<TR><TD ALIGN="right" VALIGN="top">Billing</TD><TD BGCOLOR="#ffffff">'.
      $cust_main->getfield('last'). ', '. $cust_main->first. '<BR>';
print $cust_main->company. '<BR>' if $cust_main->company;
print $cust_main->address1. '<BR>';
print $cust_main->address2. '<BR>' if $cust_main->address2;
print $cust_main->city. ', '. $cust_main->state. '  '. $cust_main->zip. '<BR>';
print $cust_main->country. '<BR>' if $cust_main->country
                                     && $cust_main->country ne $countrydefault;

print '</TD>'.
      '</TR></TABLE></TD>';

if ( defined $cust_main->dbdef_table->column('ship_last') ) {

  my $pre = $cust_main->ship_last ? 'ship_' : '';

  print '<TD>'. ntable("#cccccc",2).
        '<TR><TD ALIGN="right" VALIGN="top">Service</TD><TD BGCOLOR="#ffffff">'.
        $cust_main->get("${pre}last"). ', '.
        $cust_main->get("${pre}first"). '<BR>';
  print $cust_main->get("${pre}company"). '<BR>'
    if $cust_main->get("${pre}company");
  print $cust_main->get("${pre}address1"). '<BR>';
  print $cust_main->get("${pre}address2"). '<BR>'
    if $cust_main->get("${pre}address2");
  print $cust_main->get("${pre}city"). ', '.
        $cust_main->get("${pre}state"). '  '.
        $cust_main->get("${pre}ship_zip"). '<BR>';
  print $cust_main->get("${pre}country"). '<BR>'
    if $cust_main->get("${pre}country")
       && $cust_main->get("${pre}country") ne $countrydefault;

  print '</TD>'.
        '</TR></TABLE></TD>';
}

print '</TR></TABLE>';


print '<BR><BR>Payment'. ntable("#cccccc", 2).
      '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
      time2str("%D",$_date).  '</TD></TR>'.
      qq!<INPUT TYPE="hidden" NAME="_date" VALUE="$_date">!;

print qq!<TR><TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">\$<INPUT TYPE="text" NAME="paid" VALUE="$paid" SIZE=8 MAXLENGTH=8></TD></TR>!;

print qq!<TR><TD ALIGN="right">Payby</TD><TD BGCOLOR="#ffffff">$payby</TD></TR><INPUT TYPE="hidden" NAME="payby" VALUE="$payby">!;

#payinfo (check # now as payby="BILL" hardcoded.. what to do later?)
print qq!<TR><TD ALIGN="right">Check #</TD><TD BGCOLOR="#ffffff"><INPUT TYPE="text" NAME="payinfo" VALUE="$payinfo"></TD></TR>!;

#paybatch
print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="">!;

print <<END;
</TABLE>
<BR>
<INPUT TYPE="submit" VALUE="Post payment">
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

%>
