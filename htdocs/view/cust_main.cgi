#!/usr/bin/perl -Tw
#
# cust_main.cgi: View a customer
#
# Usage: cust_main.cgi custnum
#        http://server.name/path/cust_main.cgi?custnum
#
# Note: Should be run setuid freeside as user nobody.
#
# the payment history section could use some work, see below
# 
# ivan@voicenet.com 96-nov-29 -> 96-dec-11
#
# added navigation bar (go to main menu ;)
# ivan@voicenet.com 97-jan-30
#
# changes to the way credits/payments are applied (the links are here).
# ivan@voicenet.com 97-apr-21
#
# added debugging code to diagnose CPU sucking problem.
# ivan@voicenet.com 97-may-19
#
# CPU sucking problem was in comment code?  fixed?
# ivan@voicenet.com 97-may-22
#
# rewrote for new API
# ivan@voicenet.com 97-jul-22
#
# Changes to allow page to work at a relative position in server
# Changed 'day' to 'daytime' because Pg6.3 reserves the day word
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: cust_main.cgi,v $
# Revision 1.2  1998-11-13 11:28:08  ivan
# s/CGI-modules/CGI.pm/;, relative URL's with popurl
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs qsearch);
use FS::CGI qw(header menubar popurl table);
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_bill;
use FS::part_pkg;
use FS::cust_pkg;
use FS::part_referral;
use FS::agent;
use FS::cust_main;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

print $cgi->header, header("Customer View", menubar(
  'Main Menu' => popurl(2)
)),<<END;
    <BASEFONT SIZE=3>
END

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my($custnum)=$1;
my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;
my($hashref)=$cust_main->hashref;

#custnum
print "<FONT SIZE=+1><CENTER>Customer #<B>$custnum</B></CENTER></FONT>",
      qq!<CENTER><A HREF="#cust_main">Customer Information</A> | !,
      qq!<A HREF="#cust_comments">Comments</A> | !,
      qq!<A HREF="#cust_pkg">Packages</A> | !,
      qq!<A HREF="#history">Payment History</A> </CENTER>!;

#bill now linke
print qq!<HR><CENTER><A HREF="!, popurl(2), qq!/misc/bill.cgi?$custnum">!,
      qq!Bill this customer now</A></CENTER>!;

#formatting
print qq!<HR><A NAME="cust_main"><CENTER><FONT SIZE=+1>Customer Information!,
      qq!</FONT>!,
      qq!<BR><A HREF="!, popurl(2), qq!/edit/cust_main.cgi?$custnum!,
      qq!">Edit this information</A></CENTER><FONT SIZE=-1>!;

#agentnum
my($agent)=qsearchs('agent',{
  'agentnum' => $cust_main->getfield('agentnum')
} );
die "Agent not found!" unless $agent;
print "<BR>Agent #<B>" , $agent->getfield('agentnum') , ": " ,
                         $agent->getfield('agent') , "</B>";

#refnum
my($referral)=qsearchs('part_referral',{'refnum' => $cust_main->refnum});
die "Referral not found!" unless $referral;
print "<BR>Referral #<B>", $referral->refnum, ": ",
      $referral->referral, "<\B>"; 

#last, first
print "<P><B>", $hashref->{'last'}, ", ", $hashref->{first}, "</B>";

#ss
print " (SS# <B>", $hashref->{ss}, "</B>)" if $hashref->{ss};

#company
print "<BR><B>", $hashref->{company}, "</B>" if $hashref->{company};

#address1
print "<BR><B>", $hashref->{address1}, "</B>";

#address2
print "<BR><B>", $hashref->{address2}, "</B>" if $hashref->{address2};

#city
print "<BR><B>", $hashref->{city}, "</B>";

#county
print " (<B>", $hashref->{county}, "</B> county)" if $hashref->{county};

#state
print ",<B>", $hashref->{state}, "</B>";

#zip
print "  <B>", $hashref->{zip}, "</B>";

#country
print "<BR><B>", $hashref->{country}, "</B>"
  unless $hashref->{country} eq "US";

#daytime
print "<P><B>", $hashref->{daytime}, "</B>" if $hashref->{daytime};
print " (Day)" if $hashref->{daytime} && $hashref->{night};

#night
print "<BR><B>", $hashref->{night}, "</B>" if $hashref->{night};
print " (Night)" if $hashref->{daytime} && $hashref->{night};

#fax
print "<BR><B>", $hashref->{fax}, "</B> (Fax)" if $hashref->{fax};

#payby/payinfo/paydate/payname
if ($hashref->{payby} eq "CARD") {
  print "<P>Card #<B>", $hashref->{payinfo}, "</B> Exp. <B>",
    $hashref->{paydate}, "</B>";
  print " (<B>", $hashref->{payname}, "</B>)" if $hashref->{payname};
} elsif ($hashref->{payby} eq "BILL") {
  print "<P>Bill";
  print " on P.O. #<B>", $hashref->{payinfo}, "</B>"
    if $hashref->{payinfo};
  print " until <B>", $hashref->{paydate}, "</B>"
    if $hashref->{paydate};
  print " to <B>", $hashref->{payname}, "</B> at above address"
    if $hashref->{payname};
} elsif ($hashref->{payby} eq "COMP") {
  print "<P>Access complimentary";
  print " courtesy of <B>", $hashref->{payinfo}, "</B>"
    if $hashref->{payinfo};
  print " until <B>", $hashref->{paydate}, "</B>"
    if $hashref->{paydate};
} else {
  print "Unknown payment type ", $hashref->{payby}, "!";
}

#tax
print "<BR>(Tax exempt)" if $hashref->{tax};

#otaker
print "<P>Order taken by <B>", $hashref->{otaker}, "</B>";

#formatting	
print qq!<HR><FONT SIZE=+1><A NAME="cust_pkg"><CENTER>Packages</A></FONT>!,
      qq!<BR>Click on package number to view/edit package.!,
      qq!<BR><A HREF="!, popurl(2), qq!/edit/cust_pkg.cgi?$custnum">Add/Edit packages</A>!,
      qq!</CENTER><BR>!;

#display packages

#formatting
print qq!<CENTER>!, table, "\n",
      qq!<TR><TH ROWSPAN=2>#</TH><TH ROWSPAN=2>Package</TH><TH COLSPAN=5>!,
      qq!Dates</TH></TR>\n!,
      qq!<TR><TH><FONT SIZE=-1>Setup</FONT></TH><TH>!,
      qq!<FONT SIZE=-1>Next bill</FONT>!,
      qq!</TH><TH><FONT SIZE=-1>Susp.</FONT></TH><TH><FONT SIZE=-1>Expire!,
      qq!</FONT></TH>!,
      qq!<TH><FONT SIZE=-1>Cancel</FONT></TH>!,
      qq!</TR>\n!;

#get package info
my(@packages)=qsearch('cust_pkg',{'custnum'=>$custnum});
my($package);
foreach $package (@packages) {
  my($pref)=$package->hashref;
  my($part_pkg)=qsearchs('part_pkg',{
    'pkgpart' => $pref->{pkgpart}
  } );
  print qq!<TR><TD><FONT SIZE=-1><A HREF="!, popurl(2), qq!/view/cust_pkg.cgi?!,
        $pref->{pkgnum}, qq!">!, 
        $pref->{pkgnum}, qq!</A></FONT></TD>!,
        "<TD><FONT SIZE=-1>", $part_pkg->getfield('pkg'), " - ",
        $part_pkg->getfield('comment'), "</FONT></TD>",
        "<TD><FONT SIZE=-1>", 
        $pref->{setup} ? time2str("%D",$pref->{setup} ) : "" ,
        "</FONT></TD>",
        "<TD><FONT SIZE=-1>", 
        $pref->{bill} ? time2str("%D",$pref->{bill} ) : "" ,
        "</FONT></TD>",
        "<TD><FONT SIZE=-1>",
        $pref->{susp} ? time2str("%D",$pref->{susp} ) : "" ,
        "</FONT></TD>",
        "<TD><FONT SIZE=-1>",
        $pref->{expire} ? time2str("%D",$pref->{expire} ) : "" ,
        "</FONT></TD>",
        "<TD><FONT SIZE=-1>",
        $pref->{cancel} ? time2str("%D",$pref->{cancel} ) : "" ,
        "</FONT></TD>",
        "</TR>";
}

#formatting
print "</TABLE></CENTER>";

#formatting
print qq!<CENTER><HR><A NAME="history"><FONT SIZE=+1>Payment History!,
      qq!</FONT></A><BR>!,
      qq!Click on invoice to view invoice/enter payment.<BR>!,
      qq!<A HREF="!, popurl(2), qq!/edit/cust_credit.cgi?$custnum">!,
      qq!Post Credit / Refund</A></CENTER><BR>!;

#get payment history
#
# major problem: this whole thing is way too sloppy.
# minor problem: the description lines need better formatting.

my(@history);

my(@bills)=qsearch('cust_bill',{'custnum'=>$custnum});
my($bill);
foreach $bill (@bills) {
  my($bref)=$bill->hashref;
  push @history,
    $bref->{_date} . qq!\t<A HREF="!. popurl(2). qq!/view/cust_bill.cgi?! .
    $bref->{invnum} . qq!">Invoice #! . $bref->{invnum} .
    qq! (Balance \$! . $bref->{owed} . qq!)</A>\t! .
    $bref->{charged} . qq!\t\t\t!;

  my(@payments)=qsearch('cust_pay',{'invnum'=> $bref->{invnum} } );
  my($payment);
  foreach $payment (@payments) {
#    my($pref)=$payment->hashref;
    my($date,$invnum,$payby,$payinfo,$paid)=($payment->getfield('_date'),
                                             $payment->getfield('invnum'),
                                             $payment->getfield('payby'),
                                             $payment->getfield('payinfo'),
                                             $payment->getfield('paid'),
                      );
    push @history,
      "$date\tPayment, Invoice #$invnum ($payby $payinfo)\t\t$paid\t\t";
  }
}

my(@credits)=qsearch('cust_credit',{'custnum'=>$custnum});
my($credit);
foreach $credit (@credits) {
  my($cref)=$credit->hashref;
  push @history,
    $cref->{_date} . "\tCredit #" . $cref->{crednum} . ", (Balance \$" .
    $cref->{credited} . ") by " . $cref->{otaker} . " - " .
    $cref->{reason} . "\t\t\t" . $cref->{amount} . "\t";

  my(@refunds)=qsearch('cust_refund',{'crednum'=> $cref->{crednum} } );
  my($refund);
  foreach $refund (@refunds) {
    my($rref)=$refund->hashref;
    push @history,
      $rref->{_date} . "\tRefund, Credit #" . $rref->{crednum} . " (" .
      $rref->{payby} . " " . $rref->{payinfo} . ") by " .
      $rref->{otaker} . " - ". $rref->{reason} . "\t\t\t\t" .
      $rref->{refund};
  }
}

        #formatting
        print "<CENTER>", table, <<END;
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

my($balance)=0;
my($item);
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
print "</TABLE></CENTER>";

#end

#formatting
print <<END;

  </BODY>
</HTML>
END

#subroutiens
sub keyfield_numerically { (split(/\t/,$a))[0] <=> (split(/\t/,$b))[0] ; }

