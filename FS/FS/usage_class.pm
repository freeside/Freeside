package FS::usage_class;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::usage_class - Object methods for usage_class records

=head1 SYNOPSIS

  use FS::usage_class;

  $record = new FS::usage_class \%hash;
  $record = new FS::usage_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::usage_class object represents a usage class.  Every rate detail
(see L<FS::rate_detail) has, optionally, a usage class.  FS::usage_class
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item classnum

Primary key (assigned automatically for new usage classes)

=item classname

Text name of this usage class

=item disabled

Disabled flag, empty or 'Y'


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new usage class.  To add the usage class to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'usage_class'; }

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

Checks all fields to make sure this is a valid usage class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('classnum')
    || $self->ut_text('classname')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub _populate_initial_data {
  my ($class, %opts) = @_;

  foreach ("Intrastate", "Interstate", "International") {
    my $object = $class->new( { 'classname' => $_ } );
    my $error = $object->insert;
    die "error inserting $class into database: $error\n"
      if $error;
  }

  '';

}

sub _upgrade_data {
  my $class = shift;

  return $class->_populate_initial_data(@_)
    unless scalar( qsearch( 'usage_class', {} ) );

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

