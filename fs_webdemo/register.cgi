#!/usr/bin/perl -Tw

use strict;
use vars qw( $freeside_bin $freeside_test $freeside_conf
             $datasrc $user $pass $x
             @pw_set @saltset
             $cgi $username $name $email $user_pw $crypt_pw $dbh $sth
             $header $msg
             );
use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Mail::Internet;
use Mail::Header;
use Date::Format;

$ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

$freeside_bin = '/home/freeside/bin/';
$freeside_test = '/home/freeside/test/';
$freeside_conf = '/usr/local/etc/freeside/';

$datasrc = 'DBI:mysql:http_auth';
$user = "freeside";
$pass = "maelcolm";

#my(@pw_set)= ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '!', '.', ',' );
#my(@pw_set)= ( 'a'..'z', 'A'..'Z', '0'..'9' );
@pw_set = ( 'a'..'z', '0'..'9' );
@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

###

$cgi = new CGI;

$username = $cgi->param('username');
$username =~ /^\s*([a-z][\w]{0,15})\s*$/i
  or &idiot("Illegal username.  Please use 1-16 alphanumeric characters, and start your username with a letter.");
$username = lc($1);

$name = $cgi->param('name');
$name =~ /^([\w\-\,\. ]*)$/
  or &idiot("Illegal name.  ".
            "Only alphanumerics, the dash, comma and period are legal.");
$name = $1;

$email = $cgi->param('email');
$email =~ /^([\w\-\.\+]+\@[\w\-\.]+)$/
  or &idiot("Illegal email address.");
$email = $1;

###

$user_pw = join('',map($pw_set[ int(rand $#pw_set) ], (0..7) ) );
$crypt_pw = crypt($user_pw,$saltset[int(rand(64))].$saltset[int(rand(64))]);

###

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

###

$dbh = DBI->connect( $datasrc, $user, $pass, {
	'AutoCommit' => 'true',
} ) or die "DBI->connect error: $DBI::errstr\n";
$x = $DBI::errstr; #silly; to avoid "used only once" warning

$sth = $dbh->prepare("INSERT INTO mysql_auth VALUES (". join(", ",
  $dbh->quote($username),
  $dbh->quote($crypt_pw),
  $dbh->quote('freeside'),
). ")" );

$sth->execute or &idiot($sth->errstr);

$dbh->disconnect or die $dbh->errstr;

###

$|=1;
print $cgi->header;
print <<END;
<HTML>
  <HEAD>
    <TITLE>Freeside demo registration successful</TITLE>
  </HEAD>
  <BODY BGCOLOR="#FFFFFF">
  <table>
    <tr><td>
    <p align=center>
      <img border=0 alt="Silicon Interactive Software Design" src="http://www.sisd.com/freeside/small-logo.gif">
    </td><td>
    <center><font color="#ff0000" size=7>freeside demo registration successful</font></center>
    </td></tr>
  </table>
  <P>Your sample database has been setup.  Your username, password, and URL
    have been emailed to you.
  </BODY>
</HTML>
END

###

system("/usr/bin/mysqladmin --user=$user --password=$pass ".
  "create $username >/dev/null");

open(MAPSECRETS, ">>${freeside_conf}mapsecrets")
  or die "Can\'t open ${freeside_conf}mapsecrets: $!";
print MAPSECRETS "$username secrets.$username\n";
close MAPSECRETS;

open(SECRETS, ">${freeside_conf}secrets.$username")
  or die "Can\'t open ${freeside_conf}secrets.$username: $!";
chmod 0600, "${freeside_conf}secrets.$username";
print SECRETS "DBI:mysql:$username\nfreeside\nmaelcolm\n";
close SECRETS;

mkdir "${freeside_conf}conf.DBI:mysql:$username", 0755;

open(ADDRESS, ">${freeside_conf}conf.DBI:mysql:$username/address")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/address: $!";
print ADDRESS <<END;
Internet Service Provider, Inc.
1 Packet Blvd.
Router, MN  10010  

END
close ADDRESS;

open(DOMAIN, ">${freeside_conf}conf.DBI:mysql:$username/domain")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/domain: $!";
print DOMAIN "this-is-an-example-domain.tld\n";
close DOMAIN;

open(HOME, ">${freeside_conf}conf.DBI:mysql:$username/home")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/home: $!";
print HOME "/home\n";
close HOME;

open(INVOICE_FROM, ">${freeside_conf}conf.DBI:mysql:$username/invoice_from")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/invoice_from: $!";
print INVOICE_FROM "$email\n";
close INVOICE_FROM;

open(LPR, ">${freeside_conf}conf.DBI:mysql:$username/lpr")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/lpr: $!";
print LPR "cat >/dev/null\n";
close LPR;

mkdir "${freeside_conf}conf.DBI:mysql:$username/registries", 0755;
mkdir "${freeside_conf}conf.DBI:mysql:$username/registries/internic", 0755;
open(FROM, ">${freeside_conf}conf.DBI:mysql:$username/registries/internic/from")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/registries/internic/from: $!";
print FROM "$email\n";
close FROM;
open(NAMESERVERS, ">${freeside_conf}conf.DBI:mysql:$username/registries/internic/nameservers")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/registries/internic/nameservers: $!";
print NAMESERVERS <<END;
10.0.0.1 ns1.this-is-an-example-domain.tld
10.0.0.2 ns2.this-is-an-example-domain.tld
10.0.0.3 ns3.this-is-an-example-domain.tld
END
close NAMESERVERS;
open(TECH_CONTACT, ">${freeside_conf}conf.DBI:mysql:$username/registries/internic/tech_contact")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/registries/internic/tech_contact: $!";
print TECH_CONTACT "EXAMPLE-INTERNIC-HANDLE\n";
close TECH_CONTACT;
system ("cp", "${freeside_conf}.domain-template.txt",
        "${freeside_conf}conf.DBI:mysql:$username/registries/internic/template"
       );
open(TO, ">${freeside_conf}conf.DBI:mysql:$username/registries/internic/to")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/registries/internic/to: $!";
print TO "$email\n";
close TO;

open(SHELLS, ">${freeside_conf}conf.DBI:mysql:$username/shells")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/shells: $!";
print SHELLS <<END;
/bin/sh
/bin/csh
/bin/bash
/bin/tcsh
/bin/ksh
/bin/passwd
/bin/true
/bin/false

END
close SHELLS;

open(SMTPMACHINE, ">${freeside_conf}conf.DBI:mysql:$username/smtpmachine")
  or die "Can\'t open ${freeside_conf}conf.DBI:mysql:$username/smtpmachine: $!";
print SMTPMACHINE "localhost\n";
close SMTPMACHINE;

#make counter dir
mkdir("/usr/local/etc/freeside/counters.DBI:mysql:$username",0755)
  or die "Can't create counter spooldir: $!";

system("${freeside_bin}fs-setup.webdemo", "$username");
system("${freeside_test}cgi-test",
       "http://freeside.sisd.com/", $username, $user_pw);

###

$ENV{SMTPHOSTS} = "localhost";
$ENV{MAILADDRESS} = 'ivan@sisd.com';
$header = Mail::Header->new( [
  'From: ivan@sisd.com',
  "To: $email",
  'Cc: ivan-fsreg@sisd.com',
  'Sender: ivan@sisd.com',
  'Reply-To: ivan@sisd.com',
  'Date: '. time2str("%a, %d %b %Y %X %z", time),
  'Subject: Freeside demo information',
] );
$msg = Mail::Internet->new(
  'Header' => $header,
  'Body' => [
"Hello $name <$email>,\n",
"\n",
"Your sample Freeside database has been setup.\n",
"\n",
"Point your web browswer at http://freeside.sisd.com/ and use the following\n",
"authentication information:\n",
"\n",
"Username: $username\n",
"Password: $user_pw\n",
"\n",
"You may wish to subscribe to the Freeside mailing list - send a blank\n",
"message to ivan-freeside-subscribe\@sisd.com.\n",
"\n",
"-- \n",
"Ivan Kohler <ivan\@sisd.com>\n",
"20 4,16 \* \* \* saytime\n",
            ]
);
$msg->smtpsend or die "Can\'t send registration email!";

###

sub idiot {
  my($error)=@_;
  print $cgi->header, <<END;
<HTML>
  <HEAD>
    <TITLE>Registration error</TITLE>
  </HEAD>
  <BODY BGCOLOR="#FFFFFF">
    <CENTER>
    <H4>Registration error</H4>
    </CENTER>
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake,
       and submit the form again.
  </BODY>
</HTML>
END
  
  exit;
 
}
