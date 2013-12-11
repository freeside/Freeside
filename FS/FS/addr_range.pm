package FS::addr_range;

use strict;
use base qw( FS::Record );
use vars qw( %status_desc
             %status_allow_auto
             %status_allow_use
           );
use FS::Record qw( qsearch qsearchs );
use NetAddr::IP;

# metadata about status strings:
# how to describe them
%status_desc = (
  ''            => '',
  'unavailable' => 'unavailable',
);

# whether addresses in this range are available for use
%status_allow_use = (
  ''            => 1,
  'unavailable' => 0,
);

=head1 NAME

FS::addr_range - Object methods for addr_range records

=head1 SYNOPSIS

  use FS::addr_range;

  $record = new FS::addr_range \%hash;
  $record = new FS::addr_range { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::addr_range object represents a contiguous range of IP 
addresses assigned to a certain purpose.  Unlike L<FS::addr_block>,
this isn't a routing block; the range doesn't have to be aligned on 
a subnet boundary, and doesn't have a gateway or broadcast address.
It's just a range.

=over 4

=item rangenum - primary key

=item start - starting address of the range, as a dotted quad

=item length - number of addresses in the range, including start

=item status - what to do with the addresses in this range; currently can 
only be "unavailable", which makes the addresses unavailable for assignment 
to any kind of service.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new range.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'addr_range'; }

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
    $self->ut_numbern('rangenum')
    || $self->ut_ip('start')
    || $self->ut_number('length')
    || $self->ut_textn('status')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item end [ IPADDR ]

Get/set the end IP address in the range.  This isn't actually part of the
record but it's convenient.

=cut

sub end {
  my $self = shift;
  # if there's no start address, just return nothing
  my $start = NetAddr::IP->new($self->start, 0) or return '';

  my $new = shift;
  if ( $new ) {
    my $end = NetAddr::IP->new($new, 0)
      or die "bad end address $new";
    if ( $end < $start ) {
      $self->set('start', $end);
      ($end, $start) = ($start, $end);
    }
    $self->set('length', $end - $start + 1);
    return $end->addr;
  }
  my $end = $start + $self->get('length') - 1;
  $end->addr;
}

=item contains IPADDR

Checks whether IPADDR (a dotted-quad IPv4 address) is within the range.

=cut

sub contains {
  my $self = shift;
  my $addr = shift;
  $addr = NetAddr::IP->new($addr, 0)
    unless ref($addr) and UNIVERSAL::isa($addr, 'NetAddr::IP');
  return 0 unless $addr;

  my $start = NetAddr::IP->new($self->start, 0);

  return ($addr >= $start and $addr - $start < $self->length) ? 1 : 0;
} 

=item as_string

Returns a readable string showing the address range.

=cut

sub as_string {
  my $self = shift;
  my $start = NetAddr::IP->new($self->start, 0);
  my $end   = $start + $self->length;

  if ( $self->length == 1 ) {
    # then just the address
    return $self->start;
  } else { # we have to get tricksy
    my @end_octets = split('\.', $end->addr);
    $start = ($start->numeric)[0] + 0;
    $end   = ($end->numeric)[0] + 0;
    # which octets are different between start and end?
    my $delta = $end ^ $start;
    foreach (0xffffff, 0xffff, 0xff) {
      if ( $delta <= $_ ) {
      # then they are identical in the first 8/16/24 bits
        shift @end_octets;
      }
    }
    return $self->start . '-' . join('.', @end_octets);
  }
}

=item desc

Returns a semi-friendly description of the block status.

=item allow_use

Returns true if addresses in this range can be used by services, etc.

=cut

sub desc {
  my $self = shift;
  $status_desc{ $self->status };
}

sub allow_auto {
  my $self = shift;
  $status_allow_auto{ $self->status };
}

sub allow_use {
  my $self = shift;
  $status_allow_use{ $self->status };
}

=back

=head1 CLASS METHODS

=sub any_contains IPADDR

Returns all address ranges that contain IPADDR.

=cut

sub any_contains {
  my $self = shift;
  my $addr = shift;
  return grep { $_->contains($addr) } qsearch('addr_range', {});
}

=head1 DEVELOPER NOTE

L<NetAddr::IP> objects have netmasks.  When using them to represent 
range endpoints, be sure to set the netmask to I<zero> so that math on 
the address doesn't stop at the subnet boundary.  (The default is /32, 
which doesn't work very well.  Address ranges ignore subnet boundaries.

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_IP_Mixin>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

