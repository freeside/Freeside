#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.3 1998-12-17 06:17:00 ivan Exp $
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
# Revision 1.3  1998-12-17 06:17:00  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header popurl);
use FS::cust_main;

my($cgi) = new CGI;

cgisuidsetup($cgi);

#get record
my($custnum,$action,$cust_main);
my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ ) { #editing
  $custnum=$1;
  $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
  $action='Edit';
} else {
  $custnum='';
  $cust_main = create FS::cust_main ( {} );
  $cust_main->setfield('otaker',&getotaker);
  $action='Add';
}

my $p1 = popurl(1);'
print $cgi->header, header("Customer $action", ''), <<END;
    <FORM ACTION="${p1}process/cust_main.cgi" METHOD=POST>
    <PRE>
END

print qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!,
      qq!Customer #<FONT SIZE="+1"><B>!;
print $custnum ? $custnum : " (NEW)" , "</B></FONT>";

#agentnum
my($agentnum)=$cust_main->agentnum || 1; #set to first agent by default
my(@agents) = qsearch('agent',{});
print qq!\n\nAgent # <SELECT NAME="agentnum" SIZE="1">!;
my($agent);
foreach $agent (sort {
  $a->agent cmp $b->agent;
} @agents) {
    print "<OPTION" . " SELECTED"x($agent->agentnum==$agentnum),
    ">", $agent->agentnum,": ", $agent->agent, "\n";
}
print "</SELECT>";

#referral
#unless ($custnum) {
  my($refnum)=$cust_main->refnum || 0; #to avoid "arguement not numeric" error
  my(@referrals) = qsearch('part_referral',{});
  print qq!\nReferral <SELECT NAME="refnum" SIZE="1">!;
  print "<OPTION> \n";
  my($referral);
  foreach $referral (sort {
    $a->refnum <=> $b->refnum;
  } @referrals) {
    print "<OPTION" . " SELECTED"x($referral->refnum==$refnum),
    ">", $referral->refnum, ": ", $referral->referral,"\n";
  }
  print "</SELECT>";
#}

my($last,$first,$ss,$company,$address1,$address2,$city)=(
  $cust_main->last,
  $cust_main->first,
  $cust_main->ss,
  $cust_main->company,
  $cust_main->address1,
  $cust_main->address2,
  $cust_main->city,
);

print <<END;


Name (last)<INPUT TYPE="text" NAME="last" VALUE="$last"> (first)<INPUT TYPE="text" NAME="first" VALUE="$first">  SS# <INPUT TYPE="text" NAME="ss" VALUE="$ss" SIZE=11 MAXLENGTH=11>
Company <INPUT TYPE="text" NAME="company" VALUE="$company">
Address <INPUT TYPE="text" NAME="address1" VALUE="$address1" SIZE=40 MAXLENGTH=40>
        <INPUT TYPE="text" NAME="address2" VALUE="$address2" SIZE=40 MAXLENGTH=40>
City <INPUT TYPE="text" NAME="city" VALUE="$city">  State (county) / Country<SELECT NAME="state" SIZE="1">
END

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
print "</SELECT>";

my($zip,$daytime,$night,$fax)=(
  $cust_main->zip,
  $cust_main->daytime,
  $cust_main->night,
  $cust_main->fax,
);

print <<END;
  Zip <INPUT TYPE="text" NAME="zip" VALUE="$zip" SIZE=10 MAXLENGTH=10>

Phone (daytime)<INPUT TYPE="text" NAME="daytime" VALUE="$daytime" SIZE=18 MAXLENGTH=20>  (night)<INPUT TYPE="text" NAME="night" VALUE="$night" SIZE=18 MAXLENGTH=20>  (fax)<INPUT TYPE="text" NAME="fax" VALUE="$fax" SIZE=12 MAXLENGTH=12>

END

my(%payby)=(
  'CARD' => "Credit card    ",
  'BILL' => "Billing    ",
  'COMP' => "Complimentary",
);
for (qw(CARD BILL COMP)) {
  print qq!<INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
  print qq! CHECKED! if ($cust_main->payby eq "$_");
  print qq!>$payby{$_}!;
}


my($payinfo,$payname,$otaker)=(
  $cust_main->payinfo,
  $cust_main->payname,
  $cust_main->otaker,
);

my($paydate);
if ( $cust_main->paydate =~ /^(\d{4})-(\d{2})-\d{2}$/ ) {
  $paydate="$2/$1"
} elsif ( $cust_main->paydate =~ /^(\d{2})-\d{2}-(\d{4}$)/ ) {
  $paydate="$1/$2"
}
else {
  $paydate='';
}

print <<END;

  Card number ,   P.O. #   or   Authorization    <INPUT TYPE="text" NAME="payinfo" VALUE="$payinfo" SIZE=19 MAXLENGTH=19>
END

print qq!Exp. date (MM/YY or MM/YYYY)<INPUT TYPE="text" NAME="paydate" VALUE="$paydate" SIZE=8 MAXLENGTH=7>    Billing name <INPUT TYPE="text" NAME="payname" VALUE="$payname">\n<INPUT TYPE="checkbox" NAME="tax" VALUE="Y"!;
print qq! CHECKED! if $cust_main->tax eq "Y";
print qq!> Tax Exempt!;

print <<END;


Order taken by: <FONT SIZE="+1"><B>$otaker</B></FONT><INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">
</PRE>
END

print qq!<CENTER><INPUT TYPE="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!"></CENTER>!;

print <<END;

    </FORM>
  </BODY>
</HTML>
END

