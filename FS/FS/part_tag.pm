package FS::part_tag;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::part_tag - Object methods for part_tag records

=head1 SYNOPSIS

  use FS::part_tag;

  $record = new FS::part_tag \%hash;
  $record = new FS::part_tag { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_tag object represents a tag.  FS::part_tag inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item tagnum

primary key

=item tagname

tagname

=item tagdesc

tagdesc

=item tagcolor

tagcolor


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tag.  To add the tag to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_tag'; }

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

Checks all fields to make sure this is a valid tag.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('tagnum')
    || $self->ut_text('tagname')
    || $self->ut_textn('tagdesc')
    || $self->ut_textn('tagcolor')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

