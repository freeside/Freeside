package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $cgi $dbh $freeside_uid $user 
  $conf_dir $secrets $datasrc $db_user $db_pass %callback
);
use subs qw(
  getsecrets cgisetotaker
);
use Exporter;
use Carp;
use DBI;
use FS::Conf;

@ISA = qw(Exporter);
@EXPORT_OK = qw(checkeuid checkruid swapuid cgisuidsetup
                adminsuidsetup getotaker dbh datasrc getsecrets );

$freeside_uid = scalar(getpwnam('freeside'));

$conf_dir = "/usr/local/etc/freeside/";

=head1 NAME

FS::UID - Subroutines for database login and assorted other stuff

=head1 SYNOPSIS

  use FS::UID qw(adminsuidsetup cgisuidsetup dbh datasrc getotaker
  checkeuid checkruid swapuid);

  adminsuidsetup $user;

  $cgi = new CGI;
  $dbh = cgisuidsetup($cgi);

  $dbh = dbh;

  $datasrc = datasrc;

=head1 DESCRIPTION

Provides a hodgepodge of subroutines. 

=head1 SUBROUTINES

=over 4

=item adminsuidsetup USER

Sets the user to USER (see config.html from the base documentation).
Cleans the environment.
Make sure the script is running as freeside, or setuid freeside.
Opens a connection to the database.
Swaps real and effective UIDs.
Runs any defined callbacks (see below).
Returns the DBI database handle (usually you don't need this).

=cut

sub adminsuidsetup {

  $user = shift;
  croak "fatal: adminsuidsetup called without arguements" unless $user;

  $ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
  $ENV{'SHELL'} = '/bin/sh';
  $ENV{'IFS'} = " \t\n";
  $ENV{'CDPATH'} = '';
  $ENV{'ENV'} = '';
  $ENV{'BASH_ENV'} = '';

  croak "Not running uid freeside!" unless checkeuid();
  getsecrets;
  $dbh = DBI->connect($datasrc,$db_user,$db_pass, {
                          'AutoCommit' => 'true',
                          'ChopBlanks' => 'true',
  } ) or die "DBI->connect error: $DBI::errstr\n";

  swapuid(); #go to non-privledged user if running setuid freeside

  foreach ( keys %callback ) {
    &{$callback{$_}};
  }

  $dbh;
}

=item cgisuidsetup CGI_object

Stores the CGI (see L<CGI>) object for later use. (CGI::Base is depriciated)
Runs adminsuidsetup.

=cut

sub cgisuidsetup {
  $cgi=shift;
  if ( $cgi->isa('CGI::Base') ) {
    carp "Use of CGI::Base is depriciated";
  } elsif ( ! $cgi->isa('CGI') ) {
    croak "Pass a CGI object to cgisuidsetup!";
  }
  cgisetotaker; 
  adminsuidsetup($user);
}

=item cgi

Returns the CGI (see L<CGI>) object.

=cut

sub cgi {
  $cgi;
}

=item dbh

Returns the DBI database handle.

=cut

sub dbh {
  $dbh;
}

=item datasrc

Returns the DBI data source.

=cut

sub datasrc {
  $datasrc;
}

#hack for web demo
#sub setdbh {
#  $dbh=$_[0];
#}

sub suidsetup {
  croak "suidsetup depriciated";
}

=item getotaker

Returns the current Freeside user.

=cut

sub getotaker {
  $user;
}

=item cgisetotaker

Sets and returns the CGI REMOTE_USER.  $cgi should be defined as a CGI.pm
object.  Support for CGI::Base and derived classes is depriciated.

=cut

sub cgisetotaker {
  if ( $cgi && $cgi->isa('CGI::Base') && defined $cgi->var('REMOTE_USER')) {
    carp "Use of CGI::Base is depriciated";
    $user = lc ( $cgi->var('REMOTE_USER') );
  } elsif ( $cgi && $cgi->isa('CGI') && defined $cgi->remote_user ) {
    $user = lc ( $cgi->remote_user );
  } else {
    die "fatal: Can't get REMOTE_USER!";
  }
  $user;
}

=item checkeuid

Returns true if effective UID is that of the freeside user.

=cut

sub checkeuid {
  ( $> == $freeside_uid );
}

=item checkruid

Returns true if the real UID is that of the freeside user.

=cut

sub checkruid {
  ( $< == $freeside_uid );
}

=item swapuid

Swaps real and effective UIDs.

=cut

sub swapuid {
  ($<,$>) = ($>,$<) if $< != $>;
}

=item getsecrets [ USER ]

Sets the user to USER, if supplied.
Sets and returns the DBI datasource, username and password for this user from
the `/usr/local/etc/freeside/mapsecrets' file.

=cut

sub getsecrets {
  my($setuser) = shift;
  $user = $setuser if $setuser;
  die "No user!" unless $user;
  my($conf) = new FS::Conf $conf_dir;
  my($line) = grep /^\s*$user\s/, $conf->config('mapsecrets');
  die "User not found in mapsecrets!" unless $line;
  $line =~ /^\s*$user\s+(.*)$/;
  $secrets = $1;
  die "Illegal mapsecrets line for user?!" unless $secrets;
  ($datasrc, $db_user, $db_pass) = $conf->config($secrets)
    or die "Can't get secrets: $!";
  $FS::Conf::default_dir = $conf_dir. "/conf.$datasrc";
  ($datasrc, $db_user, $db_pass);
}

=back

=head1 CALLBACKS

Warning: this interface is likely to change in future releases.

A package can install a callback to be run in adminsuidsetup by putting a
coderef into the hash %FS::UID::callback :

    $coderef = sub { warn "Hi, I'm returning your call!" };
    $FS::UID::callback{'Package::Name'};

=head1 VERSION

$Id: UID.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

Too many package-global variables.

Not OO.

No capabilities yet.  When mod_perl and Authen::DBI are implemented, 
cgisuidsetup will go away as well.

Goes through contortions to support non-OO syntax with multiple datasrc's.

Callbacks are inelegant.

=head1 SEE ALSO

L<FS::Record>, L<CGI>, L<DBI>, config.html from the base documentation.

=cut

1;

