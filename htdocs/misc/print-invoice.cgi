#!/usr/bin/perl -Tw
#
# just a kludge for now, since this duplicates in a way it shouldn't stuff from
# Bill.pm (like $lpr) ivan@sisd.com 98-jun-16

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::Invoice;

my($lpr) = "|lpr -h";

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);

#untaint invnum
$QUERY_STRING =~ /^(\d*)$/;
my($invnum)=$1;
my($cust_bill)=qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

        bless($cust_bill,"FS::Invoice");
        open(LPR,$lpr) or die "Can't open $lpr: $!";
        print LPR $cust_bill->print_text; #( date )
        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

my($custnum)=$cust_bill->getfield('custnum');

$cgi->redirect("../view/cust_main.cgi?$custnum#history");

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error printing invoice</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error printing invoice</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
  </BODY>
</HTML>
END

  exit;

}

