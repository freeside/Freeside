package FS::SessionClient;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT_OK $fs_sessiond_socket);
use Exporter;
use Socket;
use FileHandle;
use IO::Handle;

$VERSION = '0.01';

@ISA = qw( Exporter );
@EXPORT_OK = qw( login logout portnum );

$fs_sessiond_socket = "/usr/local/freeside/fs_sessiond_socket";

$ENV{'PATH'} ='/usr/bin:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n" if $> != $freeside_uid;

=head1 NAME

FS::SessionClient - Freeside session client API

=head1 SYNOPSIS

  use FS::SessionClient qw( login portnum logout );

  $error = login ( {
    'username' => $username,
    'password' => $password,
    'login'    => $timestamp,
    'portnum'  => $portnum,
  } );

  $portnum = portnum( { 'ip' => $ip } ) or die "unknown ip!"
  $portnum = portnum( { 'nasnum' => $nasnum, 'nasport' => $nasport } )
    or die "unknown nasnum/nasport";

  $error = logout ( {
    'username' => $username,
    'password' => $password,
    'logout'   => $timestamp,
    'portnum'  => $portnum,
  } );

=head1 DESCRIPTION

This modules provides an API for a remote session application.

It needs to be run as the freeside user.  Because of this, the program which
calls these subroutines should be written very carefully.

=head1 SUBROUTINES

=over 4

=item login HASHREF

HASHREF should have the following keys: username, password, login and portnum.
login is a UNIX timestamp; if not specified, will default to the current time.
Starts a new session for the specified user and portnum.  The password is
optional, but must be correct if specified.

Returns a scalar error message, or the empty string for success.

=item portnum

HASHREF should contain a single key: ip, or the two keys: nasnum and nasport.
Returns a portnum suitable for the login and logout subroutines, or false
on error.

=item logout HASHREF

HASHREF should have the following keys: usrename, password, logout and portnum.
logout is a UNIX timestamp; if not specified, will default to the current time.
Starts a new session for the specified user and portnum.  The password is
optional, but must be correct if specified.

Returns a scalar error message, or the empty string for success.

=cut

sub AUTOLOAD {
  my $hashref = shift;
  my $method = $AUTOLOAD;
  $method =~ s/^.*:://;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_sessiond_socket)) or die "connect: $!";
  print SOCK "$method\n";

  print SOCK join("\n", %{$hashref}, 'END' ), "\n";
  SOCK->flush;

  chomp( my $r = <SOCK> );
  $r;
}

=back

=head1 VERSION

$Id: SessionClient.pm,v 1.3 2000-12-03 20:25:20 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<fs_sessiond>

=cut

1;



