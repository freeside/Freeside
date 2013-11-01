package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $DEBUG $me $cgi $freeside_uid $conf_dir $cache_dir
  $secrets $datasrc $db_user $db_pass $schema $dbh $driver_name
  $olddbh $AutoCommit %callback @callback $callback_hack $use_confcompat
);
use subs qw( getsecrets );
use Exporter;
use Carp qw( carp croak cluck confess );
use DBI;
use IO::File;
use FS::CurrentUser;
use File::Slurp;  # Exports read_file
use JSON;
use Try::Tiny;

@ISA = qw(Exporter);
@EXPORT_OK = qw( checkeuid checkruid cgi setcgi adminsuidsetup forksuidsetup
                 preuser_setup
                 getotaker dbh olddbh datasrc getsecrets driver_name myconnect
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
    my $conn_label = shift || 'main';

    my $secrets = getsecrets();
    # Select named connection or fall back to 'main'
    my $conn =  $secrets->{$conn_label}
                ?   $secrets->{$conn_label}
                :   $secrets->{'main'};

    my $handle = DBI->connect( 
        @{$conn}{qw/datasrc db_user db_pass/}, { 
            'AutoCommit'         => 0,
            'ChopBlanks'         => 1,
            'ShowErrorStatement' => 1,
            'pg_enable_utf8'     => 1,
            'mysql_enable_utf8'  => 1, 
        })
        or die "DBI->connect error: $DBI::errstr\n";

    # Populate these FS::UID global scalars
    $datasrc = $conn->{'datasrc'};
    $db_user = $conn->{'db_user'};
    $db_pass = $conn->{'db_pass'};
    $schema  = $conn->{'schema'};

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
    my $conn_name = shift;

    if ($conn_name) {
        $olddbh = $dbh;
        $dbh = myconnect($conn_name);
    }
    return $dbh;
}

=item olddbh 

Returns and restores the old DBI database handle

=cut

sub olddbh {
    $dbh = $olddbh;

    return $dbh;
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
    # Try to parse secrets file as JSON 
    my $json_text = read_file("$conf_dir/secrets");
    my $json = JSON->new;
    
    my $structure = {};
    try {
        $structure  = $json->decode($json_text);
        $datasrc    = $structure->{'main'}{'datasrc'};
        $db_user    = $structure->{'main'}{'db_user'};
        $db_pass    = $structure->{'main'}{'db_pass'};
        $schema     = $structure->{'main'}{'schema'};
    }
    catch {
        ($datasrc, $db_user, $db_pass, $schema) = 
            map { /^(.*)$/; $1 } readline(new IO::File "/tmp/secrets")
            or die "Can't get secrets: $conf_dir/secrets: $!\n";
        $structure->{'main'} = {};
        $structure->{'main'}{'datasrc'} = $datasrc;
        $structure->{'main'}{'db_user'} = $db_user;
        $structure->{'main'}{'db_pass'} = $db_pass;
        $structure->{'main'}{'schema'} = $schema;
    };

    warn "Secrets file may be invalid." 
        unless $structure->{'main'}{'datasrc'} =~ /^dbi:\w+/i;

    return $structure;
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

