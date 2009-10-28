package FS::svc_www;

use strict;
use vars qw(@ISA $conf $apacheip);
#use FS::Record qw( qsearch qsearchs );
use FS::Record qw( qsearchs dbh );
use FS::svc_Common;
use FS::cust_svc;
use FS::domain_record;
use FS::svc_acct;
use FS::svc_domain;

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_www'} = sub { 
  $conf = new FS::Conf;
  $apacheip = $conf->config('apacheip');
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

sub table_info {
  {
    'name' => 'Hosting',
    'name_plural' => 'Virtual hosting services',
    'display_weight' => 40,
    'cancel_weight'  => 20,
    'fields' => {
    },
  };
};

sub table { 'svc_www'; }

=item label [ END_TIMESTAMP [ START_TIMESTAMP ] ]

Returns the zone name for this virtual host.

END_TIMESTAMP and START_TIMESTAMP can optionally be passed when dealing with
history records.

=cut

sub label {
  my $self = shift;
  $self->domain_record(@_)->zone;
}

=item insert [ , OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

Currently available options are: I<depend_jobnum>

If I<depend_jobnum> is set (to a scalar jobnum or an array reference of
jobnums), all provisioning jobs will have a dependancy on the supplied
jobnum(s) (they will not run until the specific job(s) complete(s)).

=cut

sub preinsert_hook {
  my $self = shift;

  #return '' unless $self->recnum =~ /^([\w\-]+|\@)\.(([\w\.\-]+\.)+\w+)$/;
  return '' unless $self->recnum =~ /^([\w\-]+|\@)\.(\d+)$/;

  my( $reczone, $domain_svcnum ) = ( $1, $2 );
  unless ( $apacheip ) {
    return "Configuration option apacheip not set; can't autocreate A record";
           #"for $reczone". $svc_domain->domain;
  }
  my $domain_record = new FS::domain_record {
    'svcnum'  => $domain_svcnum,
    'reczone' => $reczone,
    'recaf'   => 'IN',
    'rectype' => 'A',
    'recdata' => $apacheip,
  };
  my $error = $domain_record->insert;
  return $error if $error;

  $self->recnum($domain_record->recnum);
  return '';
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error;

  $error = $self->SUPER::delete(@_);
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

  $error = $new->SUPER::replace($old, @_);
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

Checks all fields to make sure this is a valid web virtual host.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  #my $part_svc = $x;

  my $error =
    $self->ut_numbern('svcnum')
#    || $self->ut_number('recnum')
    || $self->ut_numbern('usersvc')
    || $self->ut_anything('config')
  ;
  return $error if $error;

  if ( $self->recnum =~ /^(\d+)$/ ) {
  
    $self->recnum($1);
    return "Unknown recnum: ". $self->recnum
      unless qsearchs('domain_record', { 'recnum' => $self->recnum } );

  } elsif ( $self->recnum =~ /^([\w\-]+|\@)\.(([\w\.\-]+\.)+\w+)$/ ) {

    my( $reczone, $domain ) = ( $1, $2 );

    my $svc_domain = qsearchs( 'svc_domain', { 'domain' => $domain } )
      or return "unknown domain $domain (recnum $1.$2)";

    my $domain_record = qsearchs( 'domain_record', {
      'reczone' => $reczone,
      'svcnum' => $svc_domain->svcnum,
    });

    if ( $domain_record ) {
      $self->recnum($domain_record->recnum);
    } else {
      #insert will create it
      #$self->recnum("$reczone.$domain");
      $self->recnum("$reczone.". $svc_domain->svcnum);
    }

  } else {
    return "Illegal recnum: ". $self->recnum;
  }

  if ( $self->usersvc ) {
    return "Unknown usersvc0 (svc_acct.svcnum): ". $self->usersvc
      unless qsearchs('svc_acct', { 'svcnum' => $self->usersvc } );
  }

  $self->SUPER::check;

}

=item domain_record

Returns the FS::domain_record record for this web virtual host's zone (see
L<FS::domain_record>).

=cut

sub domain_record {
  my $self = shift;
  qsearchs('domain_record', { 'recnum' => $self->recnum } );
}

=item svc_acct

Returns the FS::svc_acct record for this web virtual host's owner (see
L<FS::svc_acct>).

=cut

sub svc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->usersvc } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::domain_record>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

