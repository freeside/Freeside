package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $DEBUG $me $cgi $freeside_uid $user $conf_dir $cache_dir
  $secrets $datasrc $db_user $db_pass $schema $dbh $driver_name
  $AutoCommit %callback @callback $callback_hack $use_confcompat
);
use subs qw( getsecrets );
use Exporter;
use Carp qw( carp croak cluck confess );
use DBI;
use IO::File;
use FS::CurrentUser;

@ISA = qw(Exporter);
@EXPORT_OK = qw( checkeuid checkruid cgi setcgi adminsuidsetup forksuidsetup
                 preuser_setup
                 getotaker dbh datasrc getsecrets driver_name myconnect
                 use_confcompat
               );

$DEBUG = 0;
$me = '[FS::UID]';

$freeside_uid = scalar(getpwnam('freeside'));

$conf_dir  = "%%%FREESIDE_CONF%%%";
$cache_dir = "%%%FREESIDE_CACHE%%%";

$AutoCommit = 1; #ours, not DBI
$use_confcompat = 1;
$callback_hack = 0;

=head1 NAME

FS::UID - Subroutines for database login and assorted other stuff

=head1 SYNOPSIS

  use FS::UID qw(adminsuidsetup dbh datasrc getotaker checkeuid checkruid);

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
  $user = shift;
  my $olduser = $user;
  warn "$me forksuidsetup starting for $user\n" if $DEBUG;

  if ( $FS::CurrentUser::upgrade_hack ) {
    $user = 'fs_bootstrap';
  } else {
    croak "fatal: adminsuidsetup called without arguements" unless $user;

    $user =~ /^([\w\-\.]+)$/ or croak "fatal: illegal user $user";
    $user = $1;
  }

  env_setup();

  db_setup($olduser);

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

sub db_setup {
  my $olduser = shift;

  croak "Not running uid freeside (\$>=$>, \$<=$<)\n" unless checkeuid();

  warn "$me forksuidsetup connecting to database\n" if $DEBUG;
  if ( $FS::CurrentUser::upgrade_hack && $olduser ) {
    $dbh = &myconnect($olduser);
  } else {
    $dbh = &myconnect();
  }
  warn "$me forksuidsetup connected to database with handle $dbh\n" if $DEBUG;

  warn "$me forksuidsetup loading schema\n" if $DEBUG;
  use FS::Schema qw(reload_dbdef dbdef);
  reload_dbdef("$conf_dir/dbdef.$datasrc")
    unless $FS::Schema::setup_hack;

  warn "$me forksuidsetup deciding upon config system to use\n" if $DEBUG;

  if ( ! $FS::Schema::setup_hack && dbdef->table('conf') ) {

    my $sth = $dbh->prepare("SELECT COUNT(*) FROM conf") or die $dbh->errstr;
    $sth->execute or die $sth->errstr;
    my $confcount = $sth->fetchrow_arrayref->[0];
  
    if ($confcount) {
      $use_confcompat = 0;
    }else{
      die "NO CONFIGURATION RECORDS FOUND";
    }

  } else {
    die "NO CONFIGURATION TABLE FOUND" unless $FS::Schema::setup_hack;
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
  my $handle = DBI->connect( getsecrets(@_), { 'AutoCommit'         => 0,
                                               'ChopBlanks'         => 1,
                                               'ShowErrorStatement' => 1,
                                               'pg_enable_utf8'     => 1,
                                               #'mysql_enable_utf8'  => 1,
                                             }
                           )
    or die "DBI->connect error: $DBI::errstr\n";

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

Returns the current Freeside user.

=cut

sub getotaker {
  $user;
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

=item getsecrets [ USER ]

Sets the user to USER, if supplied.
Sets and returns the DBI datasource, username and password for this user from
the `/usr/local/etc/freeside/mapsecrets' file.

=cut

sub getsecrets {
  my($setuser) = shift;
  $user = $setuser if $setuser;

  if ( -e "$conf_dir/mapsecrets" ) {
    die "No user!" unless $user;
    my($line) = grep /^\s*($user|\*)\s/,
      map { /^(.*)$/; $1 } readline(new IO::File "$conf_dir/mapsecrets");
    confess "User $user not found in mapsecrets!" unless $line;
    $line =~ /^\s*($user|\*)\s+(.*)$/;
    $secrets = $2;
    die "Illegal mapsecrets line for user?!" unless $secrets;
  } else {
    # no mapsecrets file at all, so do the default thing
    $secrets = 'secrets';
  }

  ($datasrc, $db_user, $db_pass, $schema) = 
    map { /^(.*)$/; $1 } readline(new IO::File "$conf_dir/$secrets")
      or die "Can't get secrets: $conf_dir/$secrets: $!\n";
  undef $driver_name;

  ($datasrc, $db_user, $db_pass);
}

=item use_confcompat

Returns true whenever we should use 1.7 configuration compatibility.

=cut

sub use_confcompat {
  $use_confcompat;
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

