package FS::SignupClient;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $fs_signupd_socket);
use Exporter;
use Socket;
use IO::Handle;

$VERSION = '0.01';

@ISA = qw( Exporter );
@EXPORT_OK = qw( signup_info new_customer );

$fs_signupd_socket = "/usr/local/freeside/fs_signupd_socket";

$ENV{'PATH'} ='/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n" if $> != $freeside_uid;

=head1 NAME

FS::SignupClient - Freeside signup client API

=head1 SYNOPSIS

  use FS::SignupClient qw( signup_info new_customer );

  ( $locales, $packages, $pops ) = signup_info;

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

This module provides an API for a remote signup server.

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
  connect(SOCK, sockaddr_un($fs_signupd_socket)) or die "connect: $!";
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
    {
      'popnum' => $popnum,
      'city'   => $city,
      'state'  => $state,
      'ac'     => $ac,
      'exch'   => $exch,
    };
  } 1 .. $n_svc_acct_pop;

  close SOCK;

  \@cust_main_county, \@part_pkg, \@svc_acct_pop;
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
  connect(SOCK, sockaddr_un($fs_signupd_socket)) or die "connect: $!";
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

$Id: SignupClient.pm,v 1.1 1999-08-24 07:56:38 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<fs_signupd>, L<FS::SignupServer>, L<FS::cust_main>

=cut

1;

