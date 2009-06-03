package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $DEBUG $me $cgi $freeside_uid $user $conf_dir $cache_dir
  $secrets $datasrc $db_user $db_pass $schema $dbh $driver_name
  $AutoCommit %callback @callback $callback_hack $use_confcompat
);
use subs qw(
  getsecrets cgisetotaker
);
use Exporter;
use Carp qw(carp croak cluck confess);
use DBI;
use IO::File;
use FS::CurrentUser;

@ISA = qw(Exporter);
@EXPORT_OK = qw(checkeuid checkruid cgisuidsetup adminsuidsetup forksuidsetup
                getotaker dbh datasrc getsecrets driver_name myconnect
                use_confcompat);

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
  warn "$me forksuidsetup starting for $user\n" if $DEBUG;

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
      warn "NO CONFIGURATION RECORDS FOUND";
    }

  } else {
    warn "NO CONFIGURATION TABLE FOUND";
  }

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

  warn "$me forksuidsetup loading user\n" if $DEBUG;
  FS::CurrentUser->load_user($user);

  $dbh;
}

sub myconnect {
  my $handle = DBI->connect( getsecrets(@_), { 'AutoCommit'         => 0,
                                               'ChopBlanks'         => 1,
                                               'ShowErrorStatement' => 1,
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

No capabilities yet.  When mod_perl and Authen::DBI are implemented, 
cgisuidsetup will go away as well.

Goes through contortions to support non-OO syntax with multiple datasrc's.

Callbacks are (still) inelegant.

=head1 SEE ALSO

L<FS::Record>, L<CGI>, L<DBI>, config.html from the base documentation.

=cut

1;

