package FS::MailAdminClient;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $fs_mailadmind_socket);
use Exporter;
use Socket;
use FileHandle;
use IO::Handle;

$VERSION = '0.01';

@ISA = qw( Exporter );
@EXPORT_OK = qw( signup_info authenticate list_packages list_mailboxes delete_mailbox password_mailbox add_mailbox list_forwards list_pkg_forwards delete_forward add_forward new_customer );

$fs_mailadmind_socket = "/usr/local/freeside/fs_mailadmind_socket";

$ENV{'PATH'} ='/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n" if $> != $freeside_uid;

=head1 NAME

FS::MailAdminClient - Freeside mail administration client API

=head1 SYNOPSIS

  use FS::MailAdminClient qw( signup_info list_mailboxes  new_customer );

  ( $locales, $packages, $pops ) = signup_info;

  ( $accounts ) = list_mailboxes;

  $error = new_customer ( {
    'first'          => $first,
    'last'           => $last,
    'ss'             => $ss,
    'comapny'        => $company,
    'address1'       => $address1,
    'address2'       => $address2,
    'city'           => $city,
    'county'         => $county,
    'state'          => $state,
    'zip'            => $zip,
    'country'        => $country,
    'daytime'        => $daytime,
    'night'          => $night,
    'fax'            => $fax,
    'payby'          => $payby,
    'payinfo'        => $payinfo,
    'paydate'        => $paydate,
    'payname'        => $payname,
    'invoicing_list' => $invoicing_list,
    'pkgpart'        => $pkgpart,
    'username'       => $username,
    '_password'       => $password,
    'popnum'         => $popnum,
  } );

=head1 DESCRIPTION

This module provides an API for a remote mail administration server.

It needs to be run as the freeside user.  Because of this, the program which
calls these subroutines should be written very carefully.

=head1 SUBROUTINES

=over 4

=item signup_info

Returns three array references of hash references.

The first set of hash references is of allowable locales.  Each hash reference
has the following keys:
  taxnum
  state
  county
  country

The second set of hash references is of allowable packages.  Each hash
reference has the following keys:
  pkgpart
  pkg

The third set of hash references is of allowable POPs (Points Of Presence).
Each hash reference has the following keys:
  popnum
  city
  state
  ac
  exch

=cut

sub signup_info {
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "signup_info\n";
  SOCK->flush;

  chop ( my $n_cust_main_county = <SOCK> );
  my @cust_main_county = map {
    chop ( my $taxnum  = <SOCK> ); 
    chop ( my $state   = <SOCK> ); 
    chop ( my $county  = <SOCK> ); 
    chop ( my $country = <SOCK> );
    {
      'taxnum'  => $taxnum,
      'state'   => $state,
      'county'  => $county,
      'country' => $country,
    };
  } 1 .. $n_cust_main_county;

  chop ( my $n_part_pkg = <SOCK> );
  my @part_pkg = map {
    chop ( my $pkgpart = <SOCK> ); 
    chop ( my $pkg     = <SOCK> ); 
    {
      'pkgpart' => $pkgpart,
      'pkg'     => $pkg,
    };
  } 1 .. $n_part_pkg;

  chop ( my $n_svc_acct_pop = <SOCK> );
  my @svc_acct_pop = map {
    chop ( my $popnum = <SOCK> ); 
    chop ( my $city   = <SOCK> ); 
    chop ( my $state  = <SOCK> ); 
    chop ( my $ac     = <SOCK> );
    chop ( my $exch   = <SOCK> );
    chop ( my $loc    = <SOCK> );
    {
      'popnum' => $popnum,
      'city'   => $city,
      'state'  => $state,
      'ac'     => $ac,
      'exch'   => $exch,
      'loc'    => $loc,
    };
  } 1 .. $n_svc_acct_pop;

  close SOCK;

  \@cust_main_county, \@part_pkg, \@svc_acct_pop;
}

=item authenticate

Authentictes against a service on the remote Freeside system.  Requires a hash
reference as a parameter with the following keys:
    authuser
    _password

Returns a scalar error message of the form "authuser OK|FAILED" or an error
message.

=cut

sub authenticate {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "authenticate", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser _password
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item list_packages

Returns one array reference of hash references.

The set of hash references is of existing packages.  Each hash reference
has the following keys:
  pkgnum
  domain
  account

=cut

sub list_packages {
  my $user = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "list_packages\n", $user, "\n";
  SOCK->flush;

  chop ( my $n_packages = <SOCK> );
  my @packages = map {
    chop ( my $pkgnum  = <SOCK> ); 
    chop ( my $domain  = <SOCK> ); 
    chop ( my $account = <SOCK> ); 
    {
      'pkgnum'  => $pkgnum,
      'domain'  => $domain,
      'account' => $account,
    };
  } 1 .. $n_packages;

  close SOCK;

  \@packages;
}

=item list_mailboxes

Returns one array references of hash references.

The set of hash references is of existing accounts.  Each hash reference
has the following keys:
  svcnum
  username
  _password

=cut

sub list_mailboxes {
  my ($user, $package) = @_;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "list_mailboxes\n", $user, "\n", $package, "\n";
  SOCK->flush;

  chop ( my $n_svc_acct = <SOCK> );
  my @svc_acct = map {
    chop ( my $svcnum  = <SOCK> ); 
    chop ( my $username  = <SOCK> ); 
    chop ( my $_password   = <SOCK> ); 
    {
      'svcnum'  => $svcnum,
      'username'  => $username,
      '_password'   => $_password,
    };
  } 1 .. $n_svc_acct;

  close SOCK;

  \@svc_acct;
}

=item delete_mailbox

Deletes a mailbox service from the remote Freeside system.  Requires a hash
reference as a paramater with the following keys:
    authuser
    account

Returns a scalar error message, or the empty string for success.

=cut

sub delete_mailbox {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "delete_mailbox", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser account
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item password_mailbox

Changes the password for a mailbox service on the remote Freeside system.
  Requires a hash reference as a paramater with the following keys:
    authuser
    account
    _password

Returns a scalar error message, or the empty string for success.

=cut

sub password_mailbox {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "password_mailbox", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser account _password
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item add_mailbox

Creates a mailbox service on the remote Freeside system.  Requires a hash
reference as a parameter with the following keys:
    authuser
    package
    account
    _password

Returns a scalar error message, or the empty string for success.

=cut

sub add_mailbox {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "add_mailbox", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser package account _password
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item list_forwards

Returns one array references of hash references.

The set of hash references is of existing forwards.  Each hash reference
has the following keys:
  svcnum
  dest

=cut

sub list_forwards {
  my ($user, $service) = @_;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "list_forwards\n", $user, "\n", $service, "\n";
  SOCK->flush;

  chop ( my $n_svc_forward = <SOCK> );
  my @svc_forward = map {
    chop ( my $svcnum  = <SOCK> ); 
    chop ( my $dest  = <SOCK> ); 
    {
      'svcnum'  => $svcnum,
      'dest'  => $dest,
    };
  } 1 .. $n_svc_forward;

  close SOCK;

  \@svc_forward;
}

=item list_pkg_forwards

Returns one array references of hash references.

The set of hash references is of existing forwards.  Each hash reference
has the following keys:
  svcnum
  srcsvc
  dest

=cut

sub list_pkg_forwards {
  my ($user, $package) = @_;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "list_pkg_forwards\n", $user, "\n", $package, "\n";
  SOCK->flush;

  chop ( my $n_svc_forward = <SOCK> );
  my @svc_forward = map {
    chop ( my $svcnum  = <SOCK> ); 
    chop ( my $srcsvc  = <SOCK> ); 
    chop ( my $dest  = <SOCK> ); 
    {
      'svcnum'  => $svcnum,
      'srcsvc'  => $srcsvc,
      'dest'  => $dest,
    };
  } 1 .. $n_svc_forward;

  close SOCK;

  \@svc_forward;
}

=item delete_forward

Deletes a forward service from the remote Freeside system.  Requires a hash
reference as a paramater with the following keys:
    authuser
    svcnum

Returns a scalar error message, or the empty string for success.

=cut

sub delete_forward {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "delete_forward", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser svcnum
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item add_forward

Creates a forward service on the remote Freeside system.  Requires a hash
reference as a parameter with the following keys:
    authuser
    package
    source
    dest

Returns a scalar error message, or the empty string for success.

=cut

sub add_forward {
  my $hashref = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "add_forward", "\n";
  SOCK->flush;

  print SOCK join("\n", map { $hashref->{$_} } qw(
    authuser package source dest
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  close SOCK;

  $error;
}

=item new_customer HASHREF

Adds a customer to the remote Freeside system.  Requires a hash reference as
a paramater with the following keys:
  first
  last
  ss
  comapny
  address1
  address2
  city
  county
  state
  zip
  country
  daytime
  night
  fax
  payby
  payinfo
  paydate
  payname
  invoicing_list
  pkgpart
  username
  _password
  popnum

Returns a scalar error message, or the empty string for success.

=cut

sub new_customer {
  my $hashref = shift;

  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($fs_mailadmind_socket)) or die "connect: $!";
  print SOCK "new_customer\n";

  print SOCK join("\n", map { $hashref->{$_} } qw(
    first last ss company address1 address2 city county state zip country
    daytime night fax payby payinfo paydate payname invoicing_list
    pkgpart username _password popnum
  ) ), "\n";
  SOCK->flush;

  chop( my $error = <SOCK> );
  $error;
}

=back

=head1 VERSION

$Id: MailAdminClient.pm,v 1.1 2001-10-18 15:04:54 jeff Exp $

=head1 BUGS

=head1 SEE ALSO

L<fs_signupd>, L<FS::SignupServer>, L<FS::cust_main>

=cut

1;

