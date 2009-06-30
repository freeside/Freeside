package FS::phone_device;

use strict;
use base qw( FS::Record );
use FS::Record qw( dbh qsearchs ); # qsearch );
use FS::part_device;
use FS::svc_phone;

=head1 NAME

FS::phone_device - Object methods for phone_device records

=head1 SYNOPSIS

  use FS::phone_device;

  $record = new FS::phone_device \%hash;
  $record = new FS::phone_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::phone_device object represents a specific customer phone device, such as
a SIP phone or ATA.  FS::phone_device inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item devicenum

primary key

=item devicepart

devicepart

=item svcnum

svcnum

=item mac_addr

mac_addr


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'phone_device'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->svc_phone->export('device_insert', $self); #call device export

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->svc_phone->export('device_delete', $self); #call device export

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $new->svc_phone->export('device_replace', $new, $old); #call device export

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $mac = $self->mac_addr;
  $mac =~ s/\s+//g;
  $mac =~ s/://g;
  $self->mac_addr($mac);

  my $error = 
    $self->ut_numbern('devicenum')
    || $self->ut_foreign_key('devicepart', 'part_device', 'devicepart')
    || $self->ut_foreign_key('svcnum', 'svc_phone', 'svcnum' ) #cust_svc?
    || $self->ut_hexn('mac_addr')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_device

Returns the device type record (see L<FS::part_device>) associated with this
customer device.

=cut

sub part_device {
  my $self = shift;
  qsearchs( 'part_device', { 'devicepart' => $self->devicepart } );
}

=item svc_phone

Returns the phone number (see L<FS::svc_phone>) associated with this customer
device.

=cut

sub svc_phone {
  my $self = shift;
  qsearchs( 'svc_phone', { 'svcnum' => $self->svcnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

