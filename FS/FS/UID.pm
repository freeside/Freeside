package FS::UID;
use base qw( Exporter );

use strict;
use vars qw(
  @EXPORT_OK $DEBUG $me $cgi $freeside_uid $conf_dir $cache_dir
  $secrets $datasrc $db_user $db_pass $schema $dbh $driver_name
  $AutoCommit %callback @callback $callback_hack
);
use subs qw( getsecrets );
use Carp qw( carp croak cluck confess );
use DBI;
use IO::File;
use FS::CurrentUser;

@EXPORT_OK = qw( checkeuid checkruid cgi setcgi adminsuidsetup forksuidsetup
                 preuser_setup load_schema
                 getotaker dbh datasrc getsecrets driver_name myconnect
               );

$DEBUG = 0;
$me = '[FS::UID]';

$freeside_uid = scalar(getpwnam('freeside'));

$conf_dir  = "%%%FREESIDE_CONF%%%";
$cache_dir = "%%%FREESIDE_CACHE%%%";

$AutoCommit = 1; #ours, not DBI
$callback_hack = 0;

=head1 NAME

FS::UID - Subroutines for database login and assorted other stuff

=head1 SYNOPSIS

  use FS::UID qw(adminsuidsetup dbh datasrc checkeuid checkruid);

  $dbh = adminsuidsetup $user;

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
Runs any defined callbacks (see below).
Returns the DBI database handle (usually you don't need this).

=cut

sub adminsuidsetup {
  $dbh->disconnect if $dbh;
  &forksuidsetup(@_);
}

sub forksuidsetup {
  my $user = shift;
  warn "$me forksuidsetup starting for $user\n" if $DEBUG;

  if ( $FS::CurrentUser::upgrade_hack ) {
    $user = 'fs_bootstrap';
  } else {
    croak "fatal: adminsuidsetup called without arguements" unless $user;

    $user =~ /^([\w\-\.]+)$/ or croak "fatal: illegal user $user";
    $user = $1;
  }

  env_setup();

  db_setup();

  callback_setup();

  warn "$me forksuidsetup loading user\n" if $DEBUG;
  FS::CurrentUser->load_user($user);

  $dbh;
}

sub preuser_setup {
  $dbh->disconnect if $dbh;
  env_setup();
  db_setup();
  callback_setup();
  $dbh;
}

sub env_setup {

  $ENV{'PATH'} ='/usr/local/bin:/usr/bin:/bin';
  $ENV{'SHELL'} = '/bin/sh';
  $ENV{'IFS'} = " \t\n";
  $ENV{'CDPATH'} = '';
  $ENV{'ENV'} = '';
  $ENV{'BASH_ENV'} = '';

}

sub load_schema {
  warn "$me loading schema\n" if $DEBUG;
  getsecrets() unless $datasrc;
  use FS::Schema qw(reload_dbdef dbdef);
  reload_dbdef("$conf_dir/dbdef.$datasrc")
    unless $FS::Schema::setup_hack;
}

sub db_setup {
  croak "Not running uid freeside (\$>=$>, \$<=$<)\n" unless checkeuid();

  warn "$me forksuidsetup connecting to database\n" if $DEBUG;
  $dbh = &myconnect();

  warn "$me forksuidsetup connected to database with handle $dbh\n" if $DEBUG;

  load_schema();

  warn "$me forksuidsetup deciding upon config system to use\n" if $DEBUG;

  unless ( $FS::Schema::setup_hack ) {

    #how necessary is this now that we're no longer possibly a pre-1.9 db?
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM conf") or die $dbh->errstr;
    $sth->execute or die $sth->errstr;
    $sth->fetchrow_arrayref->[0] or die "NO CONFIGURATION RECORDS FOUND";

  }


}

sub callback_setup {

  unless ( $callback_hack ) {
    warn "$me calling callbacks\n" if $DEBUG;
    foreach ( keys %callback ) {
      &{$callback{$_}};
      # breaks multi-database installs # delete $callback{$_}; #run once
    }

    &{$_} foreach @callback;
  } else {
    warn "$me skipping callbacks (callback_hack set)\n" if $DEBUG;
  }

}

sub myconnect {
  my $handle = DBI->connect( getsecrets(), { 'AutoCommit'         => 0,
                                             'ChopBlanks'         => 1,
                                             'ShowErrorStatement' => 1,
                                             'pg_enable_utf8'     => 1,
                                             #'mysql_enable_utf8'  => 1,
                                           }
                           )
    or die "DBI->connect error: $DBI::errstr\n";

  $FS::Conf::conf_cache = undef;

  if ( $schema ) {
    use DBIx::DBSchema::_util qw(_load_driver ); #quelle hack
    my $driver = _load_driver($handle);
    if ( $driver =~ /^Pg/ ) {
      no warnings 'redefine';
      eval "sub DBIx::DBSchema::DBD::${driver}::default_db_schema {'$schema'}";
      die $@ if $@;
    }
  }

  $handle;
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

=item cgi

Returns the CGI (see L<CGI>) object.

=cut

sub cgi {
  carp "warning: \$FS::UID::cgi is undefined" unless defined($cgi);
  #carp "warning: \$FS::UID::cgi isa Apache" if $cgi && $cgi->isa('Apache');
  $cgi;
}

=item cgi CGI_OBJECT

Sets the CGI (see L<CGI>) object.

=cut

sub setcgi {
  $cgi = shift;
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

(Deprecated) Returns the current Freeside user's username.

=cut

sub getotaker {
  carp "FS::UID::getotaker deprecated";
  $FS::CurrentUser::CurrentUser->username;
}

=item checkeuid

Returns true if effective UID is that of the freeside user.

=cut

sub checkeuid {
  #$> = $freeside_uid unless $>; #huh.  mpm-itk hack
  ( $> == $freeside_uid );
}

=item checkruid

Returns true if the real UID is that of the freeside user.

=cut

sub checkruid {
  ( $< == $freeside_uid );
}

=item getsecrets

Sets and returns the DBI datasource, username and password from
the `/usr/local/etc/freeside/secrets' file.

=cut

sub getsecrets {

  ($datasrc, $db_user, $db_pass, $schema) = 
    map { /^(.*)$/; $1 } readline(new IO::File "$conf_dir/secrets")
      or die "Can't get secrets: $conf_dir/secrets: $!\n";
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

No capabilities yet. (What does this mean again?)

Goes through contortions to support non-OO syntax with multiple datasrc's.

Callbacks are (still) inelegant.

=head1 SEE ALSO

L<FS::Record>, L<CGI>, L<DBI>, config.html from the base documentation.

=cut

1;

