package FS::svc_external;

use strict;
use vars qw(@ISA); # $conf
use FS::UID;
#use FS::Record qw( qsearch qsearchs dbh);
use FS::svc_Common;

@ISA = qw( FS::svc_Common );

#FS::UID::install_callback( sub {
#  $conf = new FS::Conf;
#};

=head1 NAME

FS::svc_external - Object methods for svc_external records

=head1 SYNOPSIS

  use FS::svc_external;

  $record = new FS::svc_external \%hash;
  $record = new FS::svc_external { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_external object represents a externally tracked service.
FS::svc_external inherits from FS::svc_Common.  The following fields are
currently supported:

=over 4

=item svcnum - primary key

=item id - unique number of external record

=item title - for invoice line items

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new external service.  To add the external service to the database,
see L<"insert">.  

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_external'; }

=item insert

Adds this external service to the database.  If there is an error, returns the
error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

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

Checks all fields to make sure this is a valid external service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_number('id')
    || $self->ut_textn('title')
  ;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

