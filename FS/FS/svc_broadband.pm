package FS::svc_broadband;

use strict;
use vars qw(@ISA $conf);
#use FS::Record qw( qsearch qsearchs );
use FS::Record qw( qsearchs qsearch dbh );
use FS::svc_Common;
use FS::cust_svc;
use NetAddr::IP;

@ISA = qw( FS::svc_Common );

$FS::UID::callback{'FS::svc_broadband'} = sub { 
  $conf = new FS::Conf;
};

=head1 NAME

FS::svc_broadband - Object methods for svc_broadband records

=head1 SYNOPSIS

  use FS::svc_broadband;

  $record = new FS::svc_broadband \%hash;
  $record = new FS::svc_broadband { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_broadband object represents a 'broadband' Internet connection, such
as a DSL, cable modem, or fixed wireless link.  These services are assumed to
have the following properties:

=over 2

=item
The network consists of one or more 'Access Concentrators' (ACs), such as
DSLAMs or wireless access points.  (See L<FS::ac>.)

=item
Each AC provides connectivity to one or more contiguous blocks of IP addresses,
each described by a gateway address and a netmask.  (See L<FS::ac_block>.)

=item
Each connection has one or more static IP addresses within one of these blocks.

=item
The details of configuring routers and other devices are to be handled by a 
site-specific L<FS::part_export> subclass.

=back

FS::svc_broadband inherits from FS::svc_Common.  The following fields are
currently supported:

=over 4

=item svcnum - primary key

=item
actypenum - access concentrator type; see L<FS::ac_type>.  This is included here
so that a part_svc can specifically be a 'wireless' or 'DSL' service by
designating actypenum as a fixed field.  It does create a redundant functional
dependency between this table and ac_type, in that the matching ac_type could
be found by looking up the IP address in ac_block and then finding the block's
AC, but part_svc can't do that, and we don't feel like hacking it so that it
can.

=item
speed_up - maximum upload speed, in bits per second.  If set to zero, upload
speed will be unlimited.  Exports that do traffic shaping should handle this
correctly, and not blindly set the upload speed to zero and kill the customer's
connection.

=item
speed_down - maximum download speed, as above

=item
ip_addr - the customer's IP address.  If the customer needs more than one IP
address, set this to the address of the customer's router.  As a result, the
customer's router will have the same address for both it's internal and external
interfaces thus saving address space.  This has been found to work on most NAT
routers available.

=item
ip_netmask - the customer's netmask, as a single integer in the range 0-32.
(E.g. '24', not '255.255.255.0'.  We assume that address blocks are contiguous.)
This should be 32 unless the customer has multiple IP addresses.

=item
mac_addr - the MAC address of the customer's router or other device directly
connected to the network, if needed.  Some systems (e.g. DHCP, MAC address-based
access control) may need this.  If not, you may leave it blank.

=item
location - a human-readable description of the location of the connected site,
such as its address.  This should not be used for billing or contact purposes;
that information is stored in L<FS::cust_main>.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_broadband.  To add the record to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_broadband'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

# sub insert {}
# Standard FS::svc_Common::insert
# (any necessary Deep Magic is handled by exports)

=item delete

Delete this record from the database.

=cut

# Standard FS::svc_Common::delete

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# Standard FS::svc_Common::replace
# Notice a pattern here?

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid broadband service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $x = $self->setfixed;

  return $x unless ref($x);

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_foreign_key('actypenum', 'ac_type', 'actypenum')
    || $self->ut_number('speed_up')
    || $self->ut_number('speed_down')
    || $self->ut_ip('ip_addr')
    || $self->ut_numbern('ip_netmask')
    || $self->ut_textn('mac_addr')
    || $self->ut_textn('location')
  ;
  return $error if $error;

  if($self->speed_up < 0) { return 'speed_up must be positive'; }
  if($self->speed_down < 0) { return 'speed_down must be positive'; }

  # This should catch errors in the ip_addr and ip_netmask.  If it doesn't,
  # they'll almost certainly not map into a valid block anyway.
  my $self_addr = new NetAddr::IP ($self->ip_addr, $self->ip_netmask);
  return 'Cannot parse address: ' . $self->ip_addr . '/' . $self->ip_netmask unless $self_addr;

  my @block = grep { 
    my $block_addr = new NetAddr::IP ($_->ip_gateway, $_->ip_netmask);
    if ($block_addr->contains($self_addr)) { $_ };
  } qsearch( 'ac_block', { acnum => $self->acnum });

  if(scalar @block == 0) {
    return 'Block not found for address '.$self->ip_addr.' in actype '.$self->actypenum;
  } elsif(scalar @block > 1) {
    return 'ERROR: Intersecting blocks found for address '.$self->ip_addr.' :'.
        join ', ', map {$_->ip_addr . '/' . $_->ip_netmask} @block;
  }
  # OK, we've found a valid block.  We don't actually _do_ anything with it, though; we 
  # just take comfort in the knowledge that it exists.

  # A simple qsearchs won't work here.  Since we can assign blocks to customers,
  # we have to make sure the new address doesn't fall within someone else's
  # block.  Ugh.

  my @conflicts = grep {
    my $cust_addr = new NetAddr::IP($_->ip_addr, $_->ip_netmask);
    if (($cust_addr->contains($self_addr)) and
        ($_->svcnum ne $self->svcnum)) { $_; };
  } qsearch('svc_broadband', {});

  if (scalar @conflicts > 0) {
    return 'Address in use by existing service';
  }

  # Are we trying to use a network, broadcast, or the AC's address?
  foreach (qsearch('ac_block', { acnum => $self->acnum })) {
    my $block_addr = new NetAddr::IP($_->ip_gateway, $_->ip_netmask);
    if ($block_addr->network->addr eq $self_addr->addr) {
      return 'Address is network address for block '. $block_addr->network;
    }
    if ($block_addr->broadcast->addr eq $self_addr->addr) {
      return 'Address is broadcast address for block '. $block_addr->network;
    }
    if ($block_addr->addr eq $self_addr->addr) {
      return 'Address belongs to the access concentrator: '. $block_addr->addr;
    }
  }

  ''; #no error
}

=item ac_block

Returns the FS::ac_block record (i.e. the address block) for this broadband service.

=cut

sub ac_block {
  my $self = shift;
  my $self_addr = new NetAddr::IP ($self->ip_addr, $self->ip_netmask);

  foreach my $block (qsearch( 'ac_block', {} )) {
    my $block_addr = new NetAddr::IP ($block->ip_addr, $block->ip_netmask);
    if($block_addr->contains($self_addr)) { return $block; }
  }
  return '';
}

=item ac_type

Returns the FS::ac_type record for this broadband service.

=cut

sub ac_type {
  my $self = shift;
  return qsearchs('ac_type', { actypenum => $self->actypenum });
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::ac_type>, L<FS::ac_block>,
L<FS::part_svc>, schema.html from the base documentation.

=cut

1;

