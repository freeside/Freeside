package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $cgi $dbh $freeside_uid $user 
  $conf_dir $secrets $datasrc $db_user $db_pass %callback @callback
  $driver_name $AutoCommit
);
use subs qw(
  getsecrets cgisetotaker
);
use Exporter;
use Carp qw(carp croak cluck confess);
use DBI;
use FS::Conf;
use FS::CurrentUser;

@ISA = qw(Exporter);
@EXPORT_OK = qw(checkeuid checkruid cgisuidsetup adminsuidsetup forksuidsetup
                getotaker dbh datasrc getsecrets driver_name myconnect );

$freeside_uid = scalar(getpwnam('freeside'));

$conf_dir = "%%%FREESIDE_CONF%%%/";

$AutoCommit = 1; #ours, not DBI

=head1 NAME

FS::UID - Subroutines for database login and assorted other stuff

=head1 SYNOPSIS

  use FS::UID qw(adminsuidsetup cgisuidsetup dbh datasrc getotaker
  checkeuid checkruid);

  adminsuidsetup $user;

  $cgi = new CGI;
  $dbh = cgisuidsetup($cgi);

  $dbh = dbh;

  $datasrc = datasrc;

  $driver_name = driver_name;

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
  $dbh->disconnect if $dbh;
  &forksuidsetup(@_);
}

sub forksuidsetup {
  $user = shift;
  my $olduser = $user;

  if ( $FS::CurrentUser::upgrade_hack ) {
    $user = 'fs_bootstrap';
  } else {
    croak "fatal: adminsuidsetup called without arguements" unless $user;

    $user =~ /^([\w\-\.]+)$/ or croak "fatal: illegal user $user";
    $user = $1;
  }

  $ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
  $ENV{'SHELL'} = '/bin/sh';
  $ENV{'IFS'} = " \t\n";
  $ENV{'CDPATH'} = '';
  $ENV{'ENV'} = '';
  $ENV{'BASH_ENV'} = '';

  croak "Not running uid freeside!" unless checkeuid();

  if ( $FS::CurrentUser::upgrade_hack && $olduser ) {
    $dbh = &myconnect($olduser);
  } else {
    $dbh = &myconnect();
  }

  use FS::Schema qw(reload_dbdef);
  reload_dbdef("$conf_dir/dbdef.$datasrc")
    unless $FS::Schema::setup_hack;

  FS::CurrentUser->load_user($user);

  foreach ( keys %callback ) {
    &{$callback{$_}};
    # breaks multi-database installs # delete $callback{$_}; #run once
  }

  &{$_} foreach @callback;

  $dbh;
}

sub myconnect {
  DBI->connect( getsecrets(@_), { 'AutoCommit'         => 0,
                                  'ChopBlanks'         => 1,
                                  'ShowErrorStatement' => 1,
                                }
              )
    or die "DBI->connect error: $DBI::errstr\n";
}

=item install_callback

A package can install a callback to be run in adminsuidsetup by passing
a coderef to the FS::UID->install_callback class method.  If adminsuidsetup has
run already, the callback will also be run immediately.

    $coderef = sub { warn "Hi, I'm returning your call!" };
    FS::UID->install_callback($coderef);

    install_callback FS::UID sub { 
      warn "Hi, I'm returning your call!"
    };

=cut

sub install_callback {
  my $class = shift;
  my $callback = shift;
  push @callback, $callback;
  &{$callback} if $dbh;
}

=item cgisuidsetup CGI_object

Takes a single argument, which is a CGI (see L<CGI>) or Apache (see L<Apache>)
object (CGI::Base is depriciated).  Runs cgisetotaker and then adminsuidsetup.

=cut

sub cgisuidsetup {
  $cgi=shift;
  if ( $cgi->isa('CGI::Base') ) {
    carp "Use of CGI::Base is depriciated";
  } elsif ( $cgi->isa('Apache') ) {

  } elsif ( ! $cgi->isa('CGI') ) {
    croak "fatal: unrecognized object $cgi";
  }
  cgisetotaker; 
  adminsuidsetup($user);
}

=item cgi

Returns the CGI (see L<CGI>) object.

=cut

sub cgi {
  carp "warning: \$FS::UID::cgi isa Apache" if $cgi->isa('Apache');
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

=item driver_name

Returns just the driver name portion of the DBI data source.

=cut

sub driver_name {
  return $driver_name if defined $driver_name;
  $driver_name = ( split(':', $datasrc) )[1];
}

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
object (see L<CGI>) or an Apache object (see L<Apache>).  Support for CGI::Base
and derived classes is depriciated.

=cut

sub cgisetotaker {
  if ( $cgi && $cgi->isa('CGI::Base') && defined $cgi->var('REMOTE_USER')) {
    carp "Use of CGI::Base is depriciated";
    $user = lc ( $cgi->var('REMOTE_USER') );
  } elsif ( $cgi && $cgi->isa('CGI') && defined $cgi->remote_user ) {
    $user = lc ( $cgi->remote_user );
  } elsif ( $cgi && $cgi->isa('Apache') ) {
    $user = lc ( $cgi->connection->user );
  } else {
    die "fatal: Can't get REMOTE_USER! for cgi $cgi - you need to setup ".
        "Apache user authentication as documented in httemplate/docs/install.html";
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

=item getsecrets [ USER ]

Sets the user to USER, if supplied.
Sets and returns the DBI datasource, username and password for this user from
the `/usr/local/etc/freeside/mapsecrets' file.

=cut

sub getsecrets {
  my($setuser) = shift;
  $user = $setuser if $setuser;
  my($conf) = new FS::Conf $conf_dir;

  if ( $conf->exists('mapsecrets') ) {
    die "No user!" unless $user;
    my($line) = grep /^\s*($user|\*)\s/, $conf->config('mapsecrets');
    confess "User $user not found in mapsecrets!" unless $line;
    $line =~ /^\s*($user|\*)\s+(.*)$/;
    $secrets = $2;
    die "Illegal mapsecrets line for user?!" unless $secrets;
  } else {
    # no mapsecrets file at all, so do the default thing
    $secrets = 'secrets';
  }

  ($datasrc, $db_user, $db_pass) = $conf->config($secrets)
    or die "Can't get secrets: $secrets: $!\n";
  $FS::Conf::default_dir = $conf_dir. "/conf.$datasrc";
  undef $driver_name;
  ($datasrc, $db_user, $db_pass);
}

=back

=head1 CALLBACKS

Warning: this interface is (still) likely to change in future releases.

New (experimental) callback interface:

A package can install a callback to be run in adminsuidsetup by passing
a coderef to the FS::UID->install_callback class method.  If adminsuidsetup has
run already, the callback will also be run immediately.

    $coderef = sub { warn "Hi, I'm returning your call!" };
    FS::UID->install_callback($coderef);

    install_callback FS::UID sub { 
      warn "Hi, I'm returning your call!"
    };

Old (deprecated) callback interface:

A package can install a callback to be run in adminsuidsetup by putting a
coderef into the hash %FS::UID::callback :

    $coderef = sub { warn "Hi, I'm returning your call!" };
    $FS::UID::callback{'Package::Name'} = $coderef;

=head1 BUGS

Too many package-global variables.

Not OO.

No capabilities yet.  When mod_perl and Authen::DBI are implemented, 
cgisuidsetup will go away as well.

Goes through contortions to support non-OO syntax with multiple datasrc's.

Callbacks are (still) inelegant.

=head1 SEE ALSO

L<FS::Record>, L<CGI>, L<DBI>, config.html from the base documentation.

=cut

1;

