#!/usr/bin/perl -Tw
#
# s/FS:Search/FS::Record/ and cgisuidsetup($cgi) ivan@sisd.com 98-mar-13
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::Bill;

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);

#untaint custnum
$QUERY_STRING =~ /^(\d*)$/;
my($custnum)=$1;
my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
die "Can't find customer!\n" unless $cust_main;

# ? 
bless($cust_main,"FS::Bill");

my($error);

$error = $cust_main->bill(
#                          'time'=>$time
                         );
&idiot($error) if $error;

$error = $cust_main->collect(
#                             'invoice-time'=>$time,
#                             'batch_card'=> 'yes',
                             'batch_card'=> 'no',
                             'report_badcard'=> 'yes',
                            );
&idiot($error) if $error;

$cgi->redirect("../view/cust_main.cgi?$custnum#history");

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error billing customer</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error billing customer</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
  </BODY>
</HTML>
END

  exit;

}

