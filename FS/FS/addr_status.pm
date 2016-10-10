package FS::addr_status;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::addr_status;

=head1 SYNOPSIS

  use FS::addr_status;

  $record = new FS::addr_status \%hash;
  $record = new FS::addr_status { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::addr_status object represents the last known status (up or down, and
the latency) of an IP address monitored by freeside-pingd.  FS::addr_status
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item addrnum - primary key

=item ip_addr - the IP address (unique)

=item _date - the time the address was last scanned

=item up - 'Y' if the address responded to a ping

=item delay - the latency, in milliseconds

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new status record.  To add the record to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'addr_status'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

=item replace OLD_RECORD

=item check

Checks all fields to make sure this is a valid status record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('addrnum')
    || $self->ut_ip('ip_addr')
    || $self->ut_number('_date')
    || $self->ut_flag('up')
    || $self->ut_numbern('delay')
  ;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

