package FS::phone_type;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch ); # qsearchs );

=head1 NAME

FS::phone_type - Object methods for phone_type records

=head1 SYNOPSIS

  use FS::phone_type;

  $record = new FS::phone_type \%hash;
  $record = new FS::phone_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::phone_type object represents an phone number type (for example: Work,
Home, Mobile, Fax).  FS::phone_type inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item phonetypenum

Primary key

=item typename

Type name

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new type.  To add the type to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'phone_type'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid type.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('phonetypenum')
    || $self->ut_number('weight')
    || $self->ut_text('typename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

# Used by FS::Setup to initialize a new database.
sub _populate_initial_data {
  my ($class, %opts) = @_;

  my $weight = 10;

  foreach ("Work", "Home", "Mobile", "Fax") {
    my $object = $class->new({ 'typename' => $_,
                               'weight'   => $weight,
                            });
    my $error = $object->insert;
    die "error inserting $class into database: $error\n"
      if $error;

    $weight += 10;
  }

  '';

}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {
  my $class = shift;

  return $class->_populate_initial_data(@_)
    unless scalar( qsearch( 'phone_type', {} ) );

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::contact_phone>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

