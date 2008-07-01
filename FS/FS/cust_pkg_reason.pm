package FS::cust_pkg_reason;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_pkg_reason - Object methods for cust_pkg_reason records

=head1 SYNOPSIS

  use FS::cust_pkg_reason;

  $record = new FS::cust_pkg_reason \%hash;
  $record = new FS::cust_pkg_reason { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_reason object represents a relationship between a cust_pkg
and a reason, for example cancellation or suspension reasons. 
FS::cust_pkg_reason inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item num - primary key

=item pkgnum - 

=item reasonnum - 

=item otaker - 

=item date - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cust_pkg_reason.  To add the example to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pkg_reason'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid cust_pkg_reason.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_number('pkgnum')
    || $self->ut_number('reasonnum')
    || $self->ut_enum('action', [ 'A', 'C', 'E', 'S' ])
    || $self->ut_text('otaker')
    || $self->ut_numbern('date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item reason

Returns the reason (see L<FS::reason>) associated with this cust_pkg_reason.

=cut

sub reason {
  my $self = shift;
  qsearchs( 'reason', { 'reasonnum' => $self->reasonnum } );
}

=item reasontext

Returns the text of the reason (see L<FS::reason>) associated with this
cust_pkg_reason.

=cut

sub reasontext {
  my $reason = shift->reason;
  $reason ? $reason->reason : '';
}

=back

=head1 BUGS

Here be termites.  Don't use on wooden computers.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

