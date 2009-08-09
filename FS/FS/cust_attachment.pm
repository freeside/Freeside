package FS::cust_attachment;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;

=head1 NAME

FS::cust_attachment - Object methods for cust_attachment records

=head1 SYNOPSIS

  use FS::cust_attachment;

  $record = new FS::cust_attachment \%hash;
  $record = new FS::cust_attachment { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_attachment object represents a file attached to a L<FS::cust_main>
object.  FS::cust_attachment inherits from FS::Record.  The following fields 
are currently supported:

=over 4

=item attachnum

Primary key (assigned automatically).

=item custnum

Customer number (see L<FS::cust_main>).

=item _date

The date the record was last updated.

=item otaker

Order taker (assigned automatically; see L<FS::UID>).

=item filename

The file's name.

=item mime_type

The Content-Type of the file.

=item body

The contents of the file.

=item disabled

If the attachment was disabled, this contains the date it was disabled.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new attachment object.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_attachment'; }

sub nohistory_fields { 'body'; }

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

  my $conf = new FS::Conf;
  my $error;
  if($conf->config('disable_cust_attachment') ) {
    $error = 'Attachments disabled (see configuration)';
  }

  $error = 
    $self->ut_numbern('attachnum')
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_text('otaker')
    || $self->ut_text('filename')
    || $self->ut_text('mime_type')
    || $self->ut_numbern('disabled')
    || $self->ut_anything('body')
  ;
  if($conf->config('max_attachment_size') 
    and $self->size > $conf->config('max_attachment_size') ) {
    $error = 'Attachment too large'
  }
  return $error if $error;

  $self->SUPER::check;
}

=item size

Returns the size of the attachment in bytes.

=cut

sub size {
  my $self = shift;
  return length($self->body);
}

=back

=head1 BUGS

Doesn't work on non-Postgres systems.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

