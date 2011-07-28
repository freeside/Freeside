package FS::template_content;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::template_content - Object methods for template_content records

=head1 SYNOPSIS

  use FS::template_content;

  $record = new FS::template_content \%hash;
  $record = new FS::template_content { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::template_content object represents the content of a message template
(subject line and body) for a specific region.  FS::template_content inherits 
from FS::Record.  The following fields are currently supported:

=over 4

=item contentnum - primary key

=item msgnum - the L<FS::msg_template> for which this is the content.

=item locale - locale (such as 'en_US'); can be NULL.

=item subject - Subject: line of the message, in L<Text::Template> format.

=item body - Message body, as plain text or HTML, in L<Text::Template> format.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'template_content'; }

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
    $self->ut_numbern('contentnum')
    || $self->ut_foreign_key('msgnum', 'msg_template', 'msgnum')
    || $self->ut_textn('locale')
    || $self->ut_anything('subject')
    || $self->ut_anything('body')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

