#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.6 1999-01-18 09:41:24 ivan Exp $
#
# Usage: cust_main.cgi custnum
#        http://server.name/path/cust_main.cgi?custnum
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 96-nov-29 -> 96-dec-04
#
# Blank custnum for new customer.
# ivan@voicenet.com 96-dec-16
#
# referral defaults to blank, to force people to pick something
# ivan@voicenet.com 97-jun-4
#
# rewrote for new API
# ivan@voicenet.com 97-jul-28
#
# new customer is null, not '#'
# otaker gotten from &getotaker instead of $ENV{REMOTE_USER}
# ivan@sisd.com 97-nov-12
#
# cgisuidsetup($cgi);
# no need for old_ fields.
# now state+county is a select field (took out PA hack)
# used autoloaded $cust_main->field methods
# ivan@sisd.com 97-dec-17
#
# fixed quoting problems ivan@sisd.com 98-feb-23
#
# paydate sql update ivan@sisd.com 98-mar-5
#
# Changes to allow page to work at a relative position in server
# Changed 'day' to 'daytime' because Pg6.3 reserves the day word
# Added test for paydate in mm-dd-yyyy format for Pg6.3 default format
#	bmccane@maxbaud.net	98-apr-3
#
# fixed one missed day->daytime ivan@sisd.com 98-jul-13
#
# $Log: cust_main.cgi,v $
# Revision 1.6  1999-01-18 09:41:24  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.5  1999/01/18 09:22:30  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.4  1998/12/23 08:08:15  ivan
# fix typo
#
# Revision 1.3  1998/12/17 06:17:00  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use CGI::Switch;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header popurl itable table);
use FS::cust_main;

my $cgi = new CGI;
cgisuidsetup($cgi);

#get record

my ( $custnum, $action, $cust_main );
if ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum=$1;
  $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  $action='Edit';
} else {
  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->setfield('otaker',&getotaker);
  $action='Add';
}

# top

my $p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Customer $action", ''),
      qq!<FORM ACTION="${p1}process/cust_main.cgi" METHOD=POST>!,
      qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!,
      qq!Customer # !, ( $custnum ? $custnum : " (NEW)" ),
      
;

# agent

my @agents = qsearch( 'agent', {} );
my $agentnum = $cust_main->agentnum || $agents[0]->agentnum; #default to first
if ( scalar(@agents) == 1 ) {
  print qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$agentnum">!;
} else {
  print qq!<BR><BR>Agent <SELECT NAME="agentnum" SIZE="1">!;
  my $agent;
  foreach $agent (sort {
    $a->agent cmp $b->agent;
  } @agents) {
      print "<OPTION" . " SELECTED"x($agent->agentnum==$agentnum),
      ">", $agent->agentnum,": ", $agent->agent;
  }
  print "</SELECT>";
}

# contact info

my($last,$first,$ss,$company,$address1,$address2,$city,$zip)=(
  $cust_main->last,
  $cust_main->first,
  $cust_main->ss,
  $cust_main->company,
  $cust_main->address1,
  $cust_main->address2,
  $cust_main->city,
  $cust_main->zip,
);

print "<BR><BR>Contact information", itable("#c0c0c0"), <<END;
<TR><TH ALIGN="right">Contact name<BR>(last, first)</TH><TD COLSPAN=3><INPUT TYPE="text" NAME="last" VALUE="$last">, <INPUT TYPE="text" NAME="first" VALUE="$first"></TD><TD ALIGN="right">SS#</TD><TD><INPUT TYPE="text" NAME="ss" VALUE="$ss" SIZE=11></TD></TR>
<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="company" VALUE="$company" SIZE=70></TD></TR>
<TR><TH ALIGN="right">Address</TH><TD COLSPAN=5><INPUT TYPE="text" NAME="address1" VALUE="$address1" SIZE=70></TH></TR>
<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="address2" VALUE="$address2" SIZE=70></TD></TR>
<TR><TH ALIGN="right">City</TH><TD><INPUT TYPE="text" NAME="city" VALUE="$city"><TH ALIGN="right">State/Country</TH><TD><SELECT NAME="state" SIZE="1">
END

$cust_main->country('US') unless $cust_main->country; #eww
foreach ( qsearch('cust_main_county',{}) ) {
  print "<OPTION";
  print " SELECTED" if ( $cust_main->state eq $_->state
                         && $cust_main->county eq $_->county 
                         && $cust_main->country eq $_->country
                       );
  print ">",$_->state;
  print " (",$_->county,")" if $_->county;
  print " / ", $_->country;
}
print qq!</SELECT></TD><TH>Zip</TH><TD><INPUT TYPE="text" NAME="zip" VALUE="$zip" SIZE=10></TD></TR>!;

my($daytime,$night,$fax)=(
  $cust_main->daytime,
  $cust_main->night,
  $cust_main->fax,
);

print <<END;
<TR><TD ALIGN="right">Day Phone</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="daytime" VALUE="$daytime" SIZE=18></TD></TR>
<TR><TD ALIGN="right">Night Phone</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="night" VALUE="$night" SIZE=18></TD></TR>
<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="fax" VALUE="$fax" SIZE=12></TD></TR>
END

print "</TABLE>";

# billing info

sub expselect {
  my $prefix = shift;
  my $date = shift || '';
  my( $m, $y ) = ( 0, 0 );
  if ( $date  =~ /^(\d{4})-(\d{2})-\d{2}$/ ) { #PostgreSQL date format
    ( $m, $y ) = ( $2, $1 );
  } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
    ( $m, $y ) = ( $1, $3 );
  }
  my $return = qq!<SELECT NAME="$prefix!. qq!_month" SIZE="1">!;
  for ( 1 .. 12 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $m;
    $return .= ">$_";
  }
  $return .= qq!</SELECT>/<SELECT NAME="$prefix!. qq!_year" SIZE="1">!;
  for ( 1999 .. 2037 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $y;
    $return .= ">$_";
  }
  $return .= "</SELECT>";

  $return;
}

print "<BR>Billing information", itable("#c0c0c0"),
      qq!<TR><TD><INPUT TYPE="checkbox" NAME="tax" VALUE="Y"!;
print qq! CHECKED! if $cust_main->tax eq "Y";
print qq!>Tax Exempt!;
print qq!</TD></TR><TR><TD><INPUT TYPE="checkbox" NAME="invoicing_list_POST" VALUE="POST"!;
my @invoicing_list = $cust_main->invoicing_list;
print qq! CHECKED!
  if ! @invoicing_list || grep { $_ eq 'POST' } @invoicing_list;
print qq!> Postal mail invoice!;
my $invoicing_list = join(', ', grep { $_ ne 'POST' } @invoicing_list );
print qq!</TD></TR><TR><TD>Email invoice <INPUT TYPE="text" NAME="invoicing_list" VALUE="$invoicing_list"></TD>!;

print "</TD></TR></TABLE>";

print table("#c0c0c0"), "<TR>";

my($payinfo, $payname)=(
  $cust_main->payinfo,
  $cust_main->payname,
);

my %payby = (
  'CARD' => qq!Credit card<BR><INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR>Exp !. expselect("CARD"). qq!<BR>Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
  'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR>Exp !. expselect("BILL", "12-2037"). qq!<BR>Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="Accounts Payable">!,
  'COMP' => qq!Complimentary<BR>Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR>Exp !. expselect("COMP"),
);
my %paybychecked = (
  'CARD' => qq!Credit card<BR><INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>Exp !. expselect("CARD", $cust_main->paydate). qq!<BR>Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
  'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR>Exp !. expselect("BILL", $cust_main->paydate). qq!<BR>Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
  'COMP' => qq!Complimentary<BR>Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR>Exp !. expselect("COMP", $cust_main->paydate),
);
for (qw(CARD BILL COMP)) {
  print qq!<TD VALIGN=TOP><INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
  if ($cust_main->payby eq "$_") {
    print qq! CHECKED> $paybychecked{$_}</TD>!;
  } else {
    print qq!> $payby{$_}</TD>!;
  }
}

print "</TR></TABLE>";

#referral

my $refnum = $cust_main->refnum || 0;
if ( $custnum ) {
  print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$refnum">!;
} else {
  my(@referrals) = qsearch('part_referral',{});
  print qq!<BR>Referral <SELECT NAME="refnum" SIZE="1">!;
  print "<OPTION> ";
  my($referral);
  foreach $referral (sort {
    $a->refnum <=> $b->refnum;
  } @referrals) {
    print "<OPTION" . " SELECTED"x($referral->refnum==$refnum),
    ">", $referral->refnum, ": ", $referral->referral;
  }
  print "</SELECT>";
}

my $otaker = $cust_main->otaker;
print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!,
      qq!<BR><BR><INPUT TYPE="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!">!,
      "</FORM></BODY></HTML>",
;

