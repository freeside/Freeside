#!/usr/bin/perl -Tw

use strict;
use Getopt::Std;
use Socket;
use IO::Handle;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

my $fs_passwdd_socket = "/usr/local/freeside/fs_passwdd_socket";
my $freeside_uid = scalar(getpwnam('freeside'));

$ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

die "fs_passwd.cgi isn't running as freeside user\n" if $> != $freeside_uid;

my $cgi = new CGI;

$cgi->param('username') =~ /^([^\n]{0,255}$)/ or die "Illegal username";
my $me = $1;

$cgi->param('old_password') =~ /^([^\n]{0,255}$)/ or die "Illegal old_password";
my $old_password = $1;

$cgi->param('new_password') =~ /^([^\n]{0,255}$)/ or die "Illegal new_password";
my $new_password = $1;

die "New passwords don't match"
  unless $new_password eq $cgi->param('new_password2');

socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
connect(SOCK, sockaddr_un($fs_passwdd_socket)) or die "connect: $!";
print SOCK join("\n", $me, $old_password, $new_password, '', ''), "\n";
SOCK->flush;
my $error = <SOCK>;
chomp $error;

if ($error) {
  die $error;
} else {
  print $cgi->header(), <<END;
<html>
  <head>
    <title>Password changed</title>
  </head>
  <body bgcolor="#e8e8e8">
    <h3>Password changed</h3>
<br>Your password has been changed.
  </body>
</html>
END
}
