package FS::msa;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::msa - Object methods for msa records

=head1 SYNOPSIS

  use FS::msa;

  $record = new FS::msa \%hash;
  $record = new FS::msa { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::msa object represents a MSA.  FS::msa inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item msanum

primary key

=item description

description


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new MSA.  To add the MSA to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'msa'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid MSA.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('msanum')
    || $self->ut_text('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub _upgrade_data {  #class method
  my ($class, %opts) = @_;
  eval "use FS::msa_Data;"; # this automatically does the upgrade if needed
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

