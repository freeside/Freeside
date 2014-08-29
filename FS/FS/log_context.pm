package FS::log_context;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

my @contexts = ( qw(
  test
  bill_and_collect
  FS::cust_main::Billing::bill_and_collect
  FS::cust_main::Billing::bill
  Cron::bill
  Cron::upload
  spool_upload
  daily
  queue
  upgrade
  upgrade_taxable_billpkgnum
) );

=head1 NAME

FS::log_context - Object methods for log_context records

=head1 SYNOPSIS

  use FS::log_context;

  $record = new FS::log_context \%hash;
  $record = new FS::log_context { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::log_context object represents a context tag attached to a log entry
(L<FS::log>).  FS::log_context inherits from FS::Record.  The following 
fields are currently supported:

=over 4

=item logcontextnum - primary key

=item lognum - lognum (L<FS::log> foreign key)

=item context - context

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new context tag.  To add the example to the database, see 
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'log_context'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('logcontextnum')
    || $self->ut_number('lognum')
    || $self->ut_text('context') #|| $self->ut_enum('context', \@contexts)
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item contexts

Returns a list of all valid contexts.

=cut

sub contexts { @contexts }

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Log>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

