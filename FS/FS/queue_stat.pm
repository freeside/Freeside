package FS::queue_stat;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::queue_stat - Object methods for queue_stat records

=head1 SYNOPSIS

  use FS::queue_stat;

  $record = new FS::queue_stat \%hash;
  $record = new FS::queue_stat { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::queue_stat object represents statistcs about a completed (queued) job.
FS::queue_stat inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item statnum

primary key

=item jobnum

jobnum

=item job

job

=item custnum

custnum

=item insert_date

insert_date

=item start_date

start_date

=item end_date

end_date

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'queue_stat'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('statnum')
    || $self->ut_number('jobnum')
    || $self->ut_text('job')
    || $self->ut_numbern('custnum')
    || $self->ut_number('insert_date')
    || $self->ut_number('start_date')
    || $self->ut_number('end_date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

