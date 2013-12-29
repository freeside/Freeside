package FS::svc_export_machine;
use base qw( FS::Record );

use strict;
use FS::cust_svc;
use FS::part_export;

sub _svc_child_partfields { ('exportnum') };

=head1 NAME

FS::svc_export_machine - Object methods for svc_export_machine records

=head1 SYNOPSIS

  use FS::svc_export_machine;

  $record = new FS::svc_export_machine \%hash;
  $record = new FS::svc_export_machine { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_export_machine object represents a customer service export
hostname.  FS::svc_export_machine inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item svcexportmachinenum

primary key

=item exportnum

Export definition, see L<FS::part_export>

=item svcnum

Customer service, see L<FS::cust_svc>

=item machinenum

Export hostname, see L<FS::part_export_machine>

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_export_machine'; }

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
    $self->ut_numbern('svcexportmachinenum')
    || $self->ut_foreign_key('svcnum',     'cust_svc',            'svcnum'    )
    || $self->ut_foreign_key('exportnum',  'part_export',         'exportnum' )
    || $self->ut_foreign_key('machinenum', 'part_export_machine', 'machinenum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_export_machine

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_svc>, L<FS::part_export_machine>, L<FS::Record>

=cut

1;

