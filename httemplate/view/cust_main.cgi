<%
#<!-- $Id: cust_main.cgi,v 1.12 2001-09-21 03:47:26 ivan Exp $ -->

use strict;
use vars qw ( $cgi $query $custnum $cust_main $hashref $agent $referral 
              @packages $package @history @bills $bill @credits $credit
              $balance $item @agents @referrals @invoicing_list $n1 $conf
              $signupurl ); 
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs qsearch);
use FS::CGI qw(header menubar popurl table itable ntable);
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_bill;
use FS::part_pkg;
use FS::cust_pkg;
use FS::part_referral;
use FS::agent;
use FS::cust_main;
use FS::cust_refund;
use FS::cust_bill_pay;
use FS::cust_credit_bill;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;

print $cgi->header( '-expires' => 'now' ), header("Customer View", menubar(
  'Main Menu' => popurl(2)
));

die "No customer specified (bad URL)!" unless $cgi->keywords;
($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
$custnum = $1;
$cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;
$hashref = $cust_main->hashref;

print qq!<A HREF="!, popurl(2), 
      qq!edit/cust_main.cgi?$custnum">Edit this customer</A>!;
print qq! | <A HREF="!, popurl(2), 
      qq!misc/delete-customer.cgi?$custnum"> Delete this customer</A>!
  if $conf->exists('deletecustomers');

unless ( $conf->exists('disable_customer_referrals') ) {
  print qq! | <A HREF="!, popurl(2),
        qq!edit/cust_main.cgi?referral_custnum=$custnum">!,
        qq!Refer a new customer</A>!;

  print qq! | <A HREF="!, popurl(2),
        qq!search/cust_main.cgi?referral_custnum=$custnum">!,
        qq!View this customer's referrals</A>!;
}

print '<BR><BR>';

my $signupurl = $conf->config('signupurl');
if ( $signupurl ) {
print "This customer's signup URL: ".
      "<a href=\"$signupurl?ref=$custnum\">$signupurl?ref=$custnum</a><BR><BR>";
}

print '<A NAME="cust_main"></A>';

print &itable(), '<TR>';

print '<TD VALIGN="top">';

  print "Billing address", &ntable("#cccccc"), "<TR><TD>",
        &ntable("#cccccc",2),
    '<TR><TD ALIGN="right">Contact name</TD>',
      '<TD COLSPAN=3 BGCOLOR="#ffffff">',
      $cust_main->last, ', ', $cust_main->first,
      '</TD><TD ALIGN="right">SS#</TD><TD BGCOLOR="#ffffff">',
      $cust_main->ss || '&nbsp', '</TD></TR>',
    '<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
      $cust_main->company,
      '</TD></TR>',
    '<TR><TD ALIGN="right">Address</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
      $cust_main->address1,
      '</TD></TR>',
  ;
  print '<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->address2, '</TD></TR>'
    if $cust_main->address2;
  print '<TR><TD ALIGN="right">City</TD><TD BGCOLOR="#ffffff">',
          $cust_main->city,
          '</TD><TD ALIGN="right">State</TD><TD BGCOLOR="#ffffff">',
          $cust_main->state,
          '</TD><TD ALIGN="right">Zip</TD><TD BGCOLOR="#ffffff">',
          $cust_main->zip, '</TD></TR>',
        '<TR><TD ALIGN="right">Country</TD><TD BGCOLOR="#ffffff">',
          $cust_main->country,
          '</TD></TR>',
  ;
  print '<TR><TD ALIGN="right">Day Phone</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->daytime || '&nbsp', '</TD></TR>',
       '<TR><TD ALIGN="right">Night Phone</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->night || '&nbsp', '</TD></TR>',
        '<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->fax || '&nbsp', '</TD></TR>',
        '</TABLE>', "</TD></TR></TABLE>"
  ;

  if ( defined $cust_main->dbdef_table->column('ship_last') ) {

    my $pre = $cust_main->ship_last ? 'ship_' : '';

    print "<BR>Service address", &ntable("#cccccc"), "<TR><TD>",
          &ntable("#cccccc",2),
      '<TR><TD ALIGN="right">Contact name</TD>',
        '<TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}last"), ', ', $cust_main->get("${pre}first"),
        '</TD></TR>',
      '<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}company"),
        '</TD></TR>',
      '<TR><TD ALIGN="right">Address</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}address1"),
        '</TD></TR>',
    ;
    print '<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->get("${pre}address2"), '</TD></TR>'
      if $cust_main->get("${pre}address2");
    print '<TR><TD ALIGN="right">City</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}city"),
            '</TD><TD ALIGN="right">State</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}state"),
            '</TD><TD ALIGN="right">Zip</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}zip"), '</TD></TR>',
          '<TR><TD ALIGN="right">Country</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}country"),
            '</TD></TR>',
    ;
    print '<TR><TD ALIGN="right">Day Phone</TD>',
          '<TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}daytime") || '&nbsp', '</TD></TR>',
          '<TR><TD ALIGN="right">Night Phone</TD>'.
          '<TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}night") || '&nbsp', '</TD></TR>',
          '<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}fax") || '&nbsp', '</TD></TR>',
          '</TABLE>', "</TD></TR></TABLE>"
    ;

  }

print '</TD>';

print '<TD VALIGN="top">';

  print &ntable("#cccccc"), "<TR><TD>", &ntable("#cccccc",2),
        '<TR><TD ALIGN="right">Customer number</TD><TD BGCOLOR="#ffffff">',
        $custnum, '</TD></TR>',
  ;

  @agents = qsearch( 'agent', {} );
  unless ( scalar(@agents) == 1 ) {
    $agent = qsearchs('agent',{ 'agentnum' => $cust_main->agentnum } );
    print '<TR><TD ALIGN="right">Agent</TD><TD BGCOLOR="#ffffff">',
        $agent->agentnum, ": ", $agent->agent, '</TD></TR>';
  } else {
    $agent = $agents[0];
  }
  @referrals = qsearch( 'part_referral', {} );
  unless ( scalar(@referrals) == 1 ) {
    my $referral = qsearchs('part_referral', {
      'refnum' => $cust_main->refnum
    } );
    print '<TR><TD ALIGN="right">Referral</TD><TD BGCOLOR="#ffffff">',
          $referral->refnum, ": ", $referral->referral, '</TD></TR>';
  }
  print '<TR><TD ALIGN="right">Order taker</TD><TD BGCOLOR="#ffffff">',
    $cust_main->otaker, '</TD></TR>';

  print '<TR><TD ALIGN="right">Referring Customer</TD><TD BGCOLOR="#ffffff">';
  my $referring_cust_main = '';
  if ( $cust_main->referral_custnum
       && ( $referring_cust_main =
            qsearchs('cust_main', { custnum => $cust_main->referral_custnum } )
          )
     ) {
    print '<A HREF="'. popurl(1). 'cust_main.cgi?'.
          $cust_main->referral_custnum. '">'.
          $cust_main->referral_custnum. ': '.
          ( $referring_cust_main->company
              ? $referring_cust_main->company. ' ('.
                  $referring_cust_main->last. ', '. $referring_cust_main->first.
                  ')'
              : $referring_cust_main->last. ', '. $referring_cust_main->first
          ).
          '</A>';
  }
  print '</TD></TR>';

  print '</TABLE></TD></TR></TABLE>';

print '<BR>';

  @invoicing_list = $cust_main->invoicing_list;
  print "Billing information (",
       qq!<A HREF="!, popurl(2), qq!misc/bill.cgi?$custnum">!, "Bill now</A>)",
        &ntable("#cccccc"), "<TR><TD>", &ntable("#cccccc",2),
        '<TR><TD ALIGN="right">Tax exempt</TD><TD BGCOLOR="#ffffff">',
        $cust_main->tax ? 'yes' : 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Postal invoices</TD><TD BGCOLOR="#ffffff">',
        ( grep { $_ eq 'POST' } @invoicing_list ) ? 'yes' : 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Email invoices</TD><TD BGCOLOR="#ffffff">',
        join(', ', grep { $_ ne 'POST' } @invoicing_list ) || 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Billing type</TD><TD BGCOLOR="#ffffff">',
  ;

  if ( $cust_main->payby eq 'CARD' ) {
    print 'Credit card</TD></TR>',
          '<TR><TD ALIGN="right">Card number</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payinfo, '</TD></TR>',
          '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
          '<TR><TD ALIGN="right">Name on card</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payname, '</TD></TR>'
    ;
  } elsif ( $cust_main->payby eq 'BILL' ) {
    print 'Billing</TD></TR>';
    print '<TR><TD ALIGN="right">P.O. </TD><TD BGCOLOR="#ffffff">',
          $cust_main->payinfo, '</TD></TR>',
      if $cust_main->payinfo;
    print '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
          '<TR><TD ALIGN="right">Attention</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payname, '</TD></TR>',
    ;
  } elsif ( $cust_main->payby eq 'COMP' ) {
    print 'Complimentary</TD></TR>',
          '<TR><TD ALIGN="right">Authorized by</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payinfo, '</TD></TR>',
          '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
    ;
  }

  print "</TABLE></TD></TR></TABLE>";

print '</TD></TR></TABLE>';

if ( defined $cust_main->dbdef_table->column('comments')
     && $cust_main->comments )
{
  print "<BR>Comments", &ntable("#cccccc"), "<TR><TD>",
        &ntable("#cccccc",2),
        '<TR><TD BGCOLOR="#ffffff"><PRE>', $cust_main->comments,
        '</PRE></TD></TR></TABLE></TABLE>';
}

print '</TD></TR></TABLE>';

print '<BR>'.
  '<FORM ACTION="'.popurl(2).'edit/process/quick-cust_pkg.cgi" METHOD="POST">'.
  qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!.
  '<SELECT NAME="pkgpart"><OPTION> ';

foreach my $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
  my $pkgpart = $type_pkgs->pkgpart;
  my $part_pkg = qsearchs('part_pkg', { 'pkgpart' => $pkgpart } )
    or do { warn "unknown type_pkgs.pkgpart $pkgpart"; next; };
  print qq!<OPTION VALUE="$pkgpart">!. $part_pkg->pkg. ' - '.
        $part_pkg->comment;
}

print '</SELECT><INPUT TYPE="submit" VALUE="Order Package"><BR>';

print qq!<BR><A NAME="cust_pkg">Packages</A> !,
#      qq!<BR>Click on package number to view/edit package.!,
      qq!( <A HREF="!, popurl(2), qq!edit/cust_pkg.cgi?$custnum">Order and cancel packages</A> (preserves services) )!,
;

#display packages

#formatting
print qq!!, &table(), "\n",
      qq!<TR><TH COLSPAN=2 ROWSPAN=2>Package</TH><TH COLSPAN=5>!,
      qq!Dates</TH><TH COLSPAN=2 ROWSPAN=2>Services</TH></TR>\n!,
      qq!<TR><TH><FONT SIZE=-1>Setup</FONT></TH><TH>!,
      qq!<FONT SIZE=-1>Next bill</FONT>!,
      qq!</TH><TH><FONT SIZE=-1>Susp.</FONT></TH><TH><FONT SIZE=-1>Expire!,
      qq!</FONT></TH>!,
      qq!<TH><FONT SIZE=-1>Cancel</FONT></TH>!,
      qq!</TR>\n!;

#get package info
if ( $conf->exists('hidecancelledpackages') ) {
  @packages = sort { $a->pkgnum <=> $b->pkgnum } ($cust_main->ncancelled_pkgs);
} else {
  @packages = sort { $a->pkgnum <=> $b->pkgnum } ($cust_main->all_pkgs);
}

$n1 = '<TR>';
foreach $package (@packages) {
  my $pkgnum = $package->pkgnum;
  my $pkg = $package->part_pkg->pkg;
  my $comment = $package->part_pkg->comment;
  my $pkgview = popurl(2). "view/cust_pkg.cgi?$pkgnum";
  my @cust_svc = qsearch( 'cust_svc', { 'pkgnum' => $pkgnum } );
  my $rowspan = scalar(@cust_svc) || 1;

  my $button_cgi = new CGI;
  $button_cgi->param('clone', $package->part_pkg->pkgpart);
  $button_cgi->param('pkgnum', $package->pkgnum);
  my $button_url = popurl(2). "edit/part_pkg.cgi?". $button_cgi->query_string;

  #print $n1, qq!<TD ROWSPAN=$rowspan><A HREF="$pkgview">$pkgnum</A></TD>!,
  print $n1, qq!<TD ROWSPAN=$rowspan>$pkgnum</TD>!,
        qq!<TD ROWSPAN=$rowspan><FONT SIZE=-1>!,
        #qq!<A HREF="$pkgview">$pkg - $comment</A>!,
        qq!$pkg - $comment!,
        qq! ( <A HREF="$pkgview">Edit</A> | <A HREF="$button_url">Customize pricing</A> )</FONT></TD>!,
  ;
  for ( qw( setup bill susp expire cancel ) ) {
    print "<TD ROWSPAN=$rowspan><FONT SIZE=-1>", ( $package->getfield($_)
            ? time2str("%D", $package->getfield($_) )
            :  '&nbsp'
          ), '</FONT></TD>',
    ;
  }

  my $n2 = '';
  foreach my $cust_svc ( @cust_svc ) {
     my($label, $value, $svcdb) = $cust_svc->label;
     my($svcnum) = $cust_svc->svcnum;
     my($sview) = popurl(2). "view";
     print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
           qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
     $n2="</TR><TR>";
  }
  $n1="</TR><TR>";
}  
print "</TR>";

#formatting
print "</TABLE>";

#formatting
print qq!<BR><BR><A NAME="history">Payment History!.
      qq!</A> ( !.
      qq!<A HREF="!. popurl(2). qq!edit/cust_pay.cgi?custnum=$custnum">!.
      qq!Post payment</A> | !.
      qq!<A HREF="!. popurl(2). qq!edit/cust_credit.cgi?$custnum">!.
      qq!Post credit</A> )!;

#get payment history
#
# major problem: this whole thing is way too sloppy.
# minor problem: the description lines need better formatting.

@history = (); #needed for mod_perl :)

@bills = qsearch('cust_bill',{'custnum'=>$custnum});
foreach $bill (@bills) {
  my($bref)=$bill->hashref;
  my $bpre = ( $bill->owed > 0 )
               ? '<b><font size="+1" color="#ff0000"> Open '
               : '';
  my $bpost = ( $bill->owed > 0 ) ? '</font></b>' : '';
  push @history,
    $bref->{_date} . qq!\t<A HREF="!. popurl(2). qq!view/cust_bill.cgi?! .
    $bref->{invnum} . qq!">${bpre}Invoice #! . $bref->{invnum} .
    qq! (Balance \$! . $bill->owed . qq!)$bpost</A>\t! .
    $bref->{charged} . qq!\t\t\t!;

  my(@cust_bill_pay)=qsearch('cust_bill_pay',{'invnum'=> $bref->{invnum} } );
#  my(@payments)=qsearch('cust_pay',{'invnum'=> $bref->{invnum} } );
#  my($payment);
#  foreach $payment (@payments) {
  foreach my $cust_bill_pay (@cust_bill_pay) {
    my $payment = $cust_bill_pay->cust_pay;
    my($date,$invnum,$payby,$payinfo,$paid)=($payment->_date,
                                             $cust_bill_pay->invnum,
                                             $payment->payby,
                                             $payment->payinfo,
                                             $cust_bill_pay->amount,
                      );
    $payinfo = substr($payinfo,0,4). 'x'x(length($payinfo)-4) if $payby eq 'CARD';
    push @history,
      "$date\tPayment, Invoice #$invnum ($payby $payinfo)\t\t$paid\t\t";
  }

  my(@cust_credit_bill)=
    qsearch('cust_credit_bill', { 'invnum'=> $bref->{invnum} } );
  foreach my $cust_credit_bill (@cust_credit_bill) {
    my $cust_credit = $cust_credit_bill->cust_credit;
    my($date, $invnum, $crednum, $amount, $reason, $app_date ) = (
      $cust_credit->_date,
      $cust_credit_bill->invnum,
      $cust_credit_bill->crednum,
      $cust_credit_bill->amount,
      $cust_credit->reason,
      time2str("%D", $cust_credit_bill->_date),
    );
    push @history,
      "$date\tCredit #$crednum: $reason<BR>".
      "(applied to invoice #$invnum on $app_date)\t\t\t$amount\t";
  }
}

@credits = grep { $_->credited > 0 }
           qsearch('cust_credit',{'custnum'=>$custnum});
foreach $credit (@credits) {
  my($cref)=$credit->hashref;
  push @history,
    $cref->{_date} . "\t" .
    qq!<A HREF="! . popurl(2). qq!edit/cust_credit_bill.cgi?!. $cref->{crednum} . qq!">!.
    '<b><font size="+1" color="#ff0000">Unapplied credit #' .
    $cref->{crednum} . "</font></b></A>: ".
    $cref->{reason} . "\t\t\t" . $credit->credited . "\t";
}

my(@refunds)=qsearch('cust_refund',{'custnum'=> $custnum } );
foreach my $refund (@refunds) {
  my($rref)=$refund->hashref;
  my($refundnum) = (
    $refund->refundnum,
  );

  push @history,
    $rref->{_date} . "\tRefund #$refundnum, (" .
    $rref->{payby} . " " . $rref->{payinfo} . ") by " .
    $rref->{otaker} . " - ". $rref->{reason} . "\t\t\t\t" .
    $rref->{refund};
}

my @unapplied_payments =
  grep { $_->unapplied > 0 } qsearch('cust_pay', { 'custnum' => $custnum } );
foreach my $payment (@unapplied_payments) {
  push @history,
    $payment->_date. "\t".
    '<A HREF="'. popurl(2). 'edit/cust_bill_pay.cgi?'. $payment->paynum. '">'.
    '<b><font size="+1" color="#ff0000">Unapplied payment #' .
    $payment->paynum . "</font></b></A>".
    "\t\t" . $payment->unapplied . "\t\t";
}

        #formatting
        print &table(), <<END;
<TR>
  <TH>Date</TH>
  <TH>Description</TH>
  <TH><FONT SIZE=-1>Charge</FONT></TH>
  <TH><FONT SIZE=-1>Payment</FONT></TH>
  <TH><FONT SIZE=-1>In-house<BR>Credit</FONT></TH>
  <TH><FONT SIZE=-1>Refund</FONT></TH>
  <TH><FONT SIZE=-1>Balance</FONT></TH>
</TR>
END

#display payment history

$balance = 0;
foreach $item (sort keyfield_numerically @history) {
  my($date,$desc,$charge,$payment,$credit,$refund)=split(/\t/,$item);
  $charge ||= 0;
  $payment ||= 0;
  $credit ||= 0;
  $refund ||= 0;
  $balance += $charge - $payment;
  $balance -= $credit - $refund;

  print "<TR><TD><FONT SIZE=-1>",time2str("%D",$date),"</FONT></TD>",
	"<TD><FONT SIZE=-1>$desc</FONT></TD>",
	"<TD><FONT SIZE=-1>",
        ( $charge ? "\$".sprintf("%.2f",$charge) : '' ),
        "</FONT></TD>",
	"<TD><FONT SIZE=-1>",
        ( $payment ? "- \$".sprintf("%.2f",$payment) : '' ),
        "</FONT></TD>",
	"<TD><FONT SIZE=-1>",
        ( $credit ? "- \$".sprintf("%.2f",$credit) : '' ),
        "</FONT></TD>",
	"<TD><FONT SIZE=-1>",
        ( $refund ? "\$".sprintf("%.2f",$refund) : '' ),
        "</FONT></TD>",
	"<TD><FONT SIZE=-1>\$" . sprintf("%.2f",$balance),
        "</FONT></TD>",
        "\n";
}

#formatting
print "</TABLE>";

#end

#formatting
print <<END;

  </BODY>
</HTML>
END

#subroutiens
sub keyfield_numerically { (split(/\t/,$a))[0] <=> (split(/\t/,$b))[0] ; }

%>
