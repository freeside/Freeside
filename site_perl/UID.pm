package FS::UID;

use strict;
use vars qw(
  @ISA @EXPORT_OK $cgi $dbh $freeside_uid $conf $datasrc $db_user $db_pass
);
use Exporter;
use Carp;
use DBI;
use FS::Conf;

@ISA = qw(Exporter);
@EXPORT_OK = qw(checkeuid checkruid swapuid cgisuidsetup
                adminsuidsetup getotaker dbh datasrc);

$freeside_uid = scalar(getpwnam('freeside'));

my $conf = new FS::Conf;
($datasrc, $db_user, $db_pass) = $conf->config('secrets')
  or die "Can't get secrets: $!";

=head1 NAME

FS::UID - Subroutines for database login and assorted other stuff

=head1 SYNOPSIS

  use FS::UID qw(adminsuidsetup cgisuidsetup dbh datasrc getotaker
  checkeuid checkruid swapuid);

  adminsuidsetup;

  $cgi = new CGI;
  $dbh = cgisuidsetup($cgi);

  $dbh = dbh;

  $datasrc = datasrc;

=head1 DESCRIPTION

Provides a hodgepodge of subroutines. 

=head1 SUBROUTINES

=over 4

=item adminsuidsetup

Cleans the environment.
Make sure the script is running as freeside, or setuid freeside.
Opens a connection to the database.
Swaps real and effective UIDs.
Returns the DBI database handle (usually you don't need this).

=cut

sub adminsuidsetup {

  $ENV{'PATH'} ='/usr/local/bin:/usr/bin:/usr/ucb:/bin';
  $ENV{'SHELL'} = '/bin/sh';
  $ENV{'IFS'} = " \t\n";
  $ENV{'CDPATH'} = '';
  $ENV{'ENV'} = '';
  $ENV{'BASH_ENV'} = '';

  croak "Not running uid freeside!" unless checkeuid();
  $dbh = DBI->connect($datasrc,$db_user,$db_pass, {
	# hack for web demo
	#  my($user)=getotaker();
	#  $dbh = DBI->connect("$datasrc:$user",$db_user,$db_pass, {
                          'AutoCommit' => 'true',
                          'ChopBlanks' => 'true',
  } ) or die "DBI->connect error: $DBI::errstr\n";;

  swapuid(); #go to non-privledged user if running setuid freeside

  $dbh;
}

=item cgisuidsetup CGI_object

Stores the CGI (see L<CGI>) object for later use. (CGI::Base is depriciated)
Runs adminsuidsetup.

=cut

sub cgisuidsetup {
  $cgi=$_[0];
  if ( $cgi->isa('CGI::Base') ) {
    carp "Use of CGI::Base is depriciated";
  } elsif ( ! $cgi->isa('CGI') ) {
    croak "Pass a CGI object to cgisuidsetup!";
  }
  adminsuidsetup;
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

Returns the current Freeside user.  Currently that means the CGI REMOTE_USER,
or 'freeside'.

=cut

sub getotaker {
  if ( $cgi && $cgi->can('var') && defined $cgi->var('REMOTE_USER')) {
    carp "Use of CGI::Base is depriciated";
    return $cgi->var('REMOTE_USER'); #for now
  } elsif ( $cgi && $cgi->can('remote_user') && defined $cgi->remote_user ) {
    return $cgi->remote_user;
  } else {
    return 'freeside';
  }
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
  ($<,$>) = ($>,$<);
}

=back

=head1 BUGS

Not OO.

No capabilities yet.  When mod_perl and Authen::DBI are implemented, 
cgisuidsetup will go away as well.

=head1 SEE ALSO

L<FS::Record>, L<CGI>, L<DBI>

=head1 HISTORY

ivan@voicenet.com 97-jun-4 - 9
 
untaint otaker ivan@voicenet.com 97-jul-7

generalize and auto-get uid (getotaker still needs to be db'ed)
ivan@sisd.com 97-nov-10

&cgisuidsetup logs into database.  other cleaning.
ivan@sisd.com 97-nov-22,23

&adminsuidsetup logs into database with otaker='freeside' (for
automated tasks like billing)
ivan@sisd.com 97-dec-13

added sub datasrc for fs-setup ivan@sisd.com 98-feb-21

datasrc, user and pass now come from conf/secrets ivan@sisd.com 98-jun-28

added ChopBlanks to DBI call (see man DBI) ivan@sisd.com 98-aug-16

pod, use FS::Conf, implemented cgisuidsetup as adminsuidsetup,
inlined suidsetup
ivan@sisd.com 98-sep-12

$Log: UID.pm,v $
Revision 1.2  1998-11-08 09:38:43  ivan
cgisuidsetup complains if you pass it a isa CGI::Base instead of an isa CGI
(first step in migrating from CGI-modules to CGI.pm)


=cut

1;

