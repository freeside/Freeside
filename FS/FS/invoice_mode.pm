package FS::invoice_mode;
use base qw(FS::Record);

use strict;
use FS::Record qw( qsearchs ); #qsearch qsearchs );
use FS::invoice_conf;

=head1 NAME

FS::invoice_mode - Object methods for invoice_mode records

=head1 SYNOPSIS

  use FS::invoice_mode;

  $record = new FS::invoice_mode \%hash;
  $record = new FS::invoice_mode { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::invoice_mode object represents an invoice rendering style.  
FS::invoice_mode inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item modenum - primary key

=item agentnum - the agent who owns this invoice mode (can be null)

=item modename - descriptive name for internal use


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice mode.  To add the object to the database, 
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'invoice_mode'; }

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
    $self->ut_numbern('modenum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('modename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item invoice_conf [ LOCALE ]

Returns the L<FS::invoice_conf> for this invoice mode, with the specified
locale.  If there isn't one with that locale, returns the one with null 
locale.  If that doesn't exist, returns nothing.

=cut

sub invoice_conf {
  my $self = shift;
  my $locale = shift;
  my $invoice_conf;
  if ( $locale ) {
    $invoice_conf = qsearchs('invoice_conf', {
        modenum => $self->modenum,
        locale  => $locale,
    });
  }
  $invoice_conf ||= qsearchs('invoice_conf', {
      modenum => $self->modenum,
      locale  => '',
  });
  $invoice_conf;
}

=item agent

Returns the agent associated with this invoice mode, if any.

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

