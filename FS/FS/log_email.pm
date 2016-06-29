package FS::log_email;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::UID qw( dbh driver_name );

=head1 NAME

FS::log_email - Object methods for log email records

=head1 SYNOPSIS

  use FS::log_email;

  $record = new FS::log_email \%hash;
  $record = new FS::log_email { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::log object represents the conditions for sending an email
when a log entry is created.  FS::log inherits from FS::Record.  
The following fields are currently supported:

=over 4

=item logemailnum - primary key

=item context - the context that will trigger the email (all contexts if unspecified)

=item min_level - the minimum log level that will trigger the email (all levels if unspecified)

=item msgnum - the msg_template that will be used to send the email

=item to_addr - who the email will be sent to (in addition to any bcc on the template)

=item context_height - number of context stack levels to match against 
(0 or null matches against full stack, 1 only matches lowest level context, 2 matches lowest two levels, etc.)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new log_email entry.

=cut

sub table { 'log_email'; }

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
    $self->ut_numbern('logemailnum')
    || $self->ut_textn('context') # not validating against list of contexts in log_context,
                                  # because not even log_context check currently does so
    || $self->ut_number('min_level')
    || $self->ut_foreign_key('msgnum', 'msg_template', 'msgnum')
    || $self->ut_textn('to_addr')
    || $self->ut_numbern('context_height')
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

