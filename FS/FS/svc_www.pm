package FS::svc_www;

use strict;
use vars qw(@ISA $conf $apacheroot $apachemachine $nossh_hack );
#use FS::Record qw( qsearch qsearchs );
use FS::Record qw( qsearchs );
use FS::svc_Common;
use FS::cust_svc;
use FS::domain_record;
use FS::svc_acct;
use Net::SSH qw(ssh);

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_www'} = sub { 
  $conf = new FS::Conf;
  $apacheroot = $conf->config('apacheroot');
  $apachemachine = $conf->config('apachemachine');
};

=head1 NAME

FS::svc_www - Object methods for svc_www records

=head1 SYNOPSIS

  use FS::svc_www;

  $record = new FS::svc_www \%hash;
  $record = new FS::svc_www { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_www object represents an web virtual host.  FS::svc_www inherits
from FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - primary key

=item recnum - DNS `A' record corresponding to this web virtual host. (see L<FS::domain_record>)

=item usersvc - account (see L<FS::svc_acct>) corresponding to this web virtual host.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new web virtual host.  To add the record to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_www'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

If the configuration values (see L<FS::Conf>) I<apachemachine>, and
I<apacheroot> exist, the command:

  mkdir $apacheroot/$zone;
  chown $username $apacheroot/$zone;
  ln -s $apacheroot/$zone $homedir/$zone

I<$zone> is the DNS A record pointed to by I<recnum>
I<$username> is the username pointed to by I<usersvc>
I<$homedir> is that user's home directory

is executed on I<apachemachine> via ssh.  This behaviour can be surpressed by
setting $FS::svc_www::nossh_hack true.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  my $domain_record = qsearchs('domain_record', { 'recnum' => $self->recnum } );    # or die ?
  my $zone = $domain_record->reczone;
    # or die ?
  unless ( $zone =~ /\.$/ ) {
    my $dom_svcnum = $domain_record->svcnum;
    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $dom_svcnum } );
      # or die ?
    $zone .= $svc_domain->domain;
  }

  my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $self->usersvc } );
    # or die ?
  my $username = $svc_acct->username;
    # or die ?
  my $homedir = $svc_acct->dir;
    # or die ?

  if ( $apachemachine
       && $apacheroot
       && $zone
       && $username
       && $homedir
       && ! $nossh_hack
  ) {
    ssh("root\@$apachemachine",
        "mkdir $apacheroot/$zone; ".
        "chown $username $apacheroot/$zone; ".
        "ln -s $apacheroot/$zone $homedir/$zone"
    );
  }

  '';
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error;

  $error = $self->SUPER::delete;
  return $error if $error;

  '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  $error = $new->SUPER::replace($old);
  return $error if $error;

  '';
}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  #my $part_svc = $x;

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_number('recnum')
    || $self->ut_number('usersvc')
  ;
  return $error if $error;

  return "Unknown recnum: ". $self->recnum
    unless qsearchs('domain_record', { 'recnum' => $self->recnum } );

  return "Unknown usersvc (svc_acct.svcnum): ". $self->usersvc
    unless qsearchs('svc_acct', { 'svcnum' => $self->usersvc } );

  ''; #no error
}

=back

=head1 VERSION

$Id: svc_www.pm,v 1.6 2001-09-06 20:41:59 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::domain_record>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

