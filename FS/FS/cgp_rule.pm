package FS::cgp_rule;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cgp_rule - Object methods for cgp_rule records

=head1 SYNOPSIS

  use FS::cgp_rule;

  $record = new FS::cgp_rule \%hash;
  $record = new FS::cgp_rule { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cgp_rule object represents an example.  FS::cgp_rule inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item rulenum

primary key

=item name

name

=item comment

comment

=item svcnum

svcnum

=item priority

priority


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cgp_rule'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('rulenum')
    || $self->ut_text('name')
    || $self->ut_text('comment')
    || $self->ut_number('svcnum')
    || $self->ut_number('priority')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

