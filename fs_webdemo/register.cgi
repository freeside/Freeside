#!/usr/bin/perl -Tw
#
# $Id: register.cgi,v 1.5 2000-03-03 18:22:42 ivan Exp $

use strict;
use vars qw(
             $datasrc $user $pass $x
             $cgi $username $email 
             $dbh $sth
             );
             #$freeside_bin $freeside_test $freeside_conf
             #@pw_set @saltset
             #$user_pw $crypt_pw 
             #$header $msg
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
#use Mail::Internet;
#use Mail::Header;
#use Date::Format;

$ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

#$freeside_bin = '/home/freeside/bin/';
#$freeside_test = '/home/freeside/test/';
#$freeside_conf = '/usr/local/etc/freeside/';

$datasrc = 'DBI:mysql:http_auth';
$user = "freeside";
$pass = "maelcolm";

##my(@pw_set)= ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '!', '.', ',' );
##my(@pw_set)= ( 'a'..'z', 'A'..'Z', '0'..'9' );
#@pw_set = ( 'a'..'z', '0'..'9' );
#@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

###

$cgi = new CGI;

$username = $cgi->param('username');
$username =~ /^\s*([a-z][\w]{0,15})\s*$/i
  or &idiot("Illegal username.  Please use 1-16 alphanumeric characters, and start your username with a letter.");
$username = lc($1);

$email = $cgi->param('email');
$email =~ /^([\w\-\.\+]+\@[\w\-\.]+)$/
  or &idiot("Illegal email address.");
$email = $1;

###

#$user_pw = join('',map($pw_set[ int(rand $#pw_set) ], (0..7) ) );
#$crypt_pw = crypt($user_pw,$saltset[int(rand(64))].$saltset[int(rand(64))]);

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
#  $dbh->quote("X"),
#  $dbh->quote($crypt_pw),
  $dbh->quote($email),
  $dbh->quote('freeside'),
  $dbh->quote('unconfigured'),
). ")" );

$sth->execute or &idiot("Username in use: ". $sth->errstr);

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
  <P>Your sample database has been setup.  Your password and the URL for the
    Freeside demo have been emailed to you.
  </BODY>
</HTML>
END

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
