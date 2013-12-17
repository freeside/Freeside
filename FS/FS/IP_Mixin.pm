package FS::IP_Mixin;

use strict;
use NetAddr::IP;
use FS::addr_block;
use FS::router;
use FS::addr_range;
use FS::Record qw(qsearch);
use FS::Conf;
# careful about importing anything here--it will end up in a LOT of 
# namespaces

use vars qw(@subclasses $DEBUG $conf);

$DEBUG = 0;

# any subclass that can have IP addresses needs to be added here
@subclasses = (qw(FS::svc_broadband FS::svc_acct));

sub conf {
  $conf ||= FS::Conf->new;
}

=head1 NAME

FS::IP_Mixin - Mixin class for objects that have IP addresses assigned.

=head1 INTERFACE

The inheritor may provide the following methods:

=over 4

=item ip_addr [ ADDRESS ]

Get/set the IP address, as a string.  If the inheritor is also an
L<FS::Record> subclass and has an 'ip_addr' field, that field will be 
used.  Otherwise an C<ip_addr> method must be defined.

=item addr_block [ BLOCK ]

Get/set the address block, as an L<FS::addr_block> object.  By default,
the 'blocknum' field will be used.

=item router [ ROUTER ]

Get/set the router, as an L<FS::router> object.  By default, the 
'routernum' field will be used.  This is strictly optional; if present
the IP address can be assigned from all those available on a router, 
rather than in a specific block.

=item _used_addresses [ BLOCK ]

Return a list of all addresses in use (within BLOCK, if it's specified).
The inheritor should cache this if possible.

=item _is_used ADDRESS

Test a specific address for availability.  Should return an empty string
if it's free, or else a description of who or what is using it.

=back

=head1 METHODS

=over 4

=item ip_check

The method that should be called from check() in the subclass.  This does 
the following:

- In an C<auto_router> situation, sets the router and block to match the 
  object's IP address.
- Otherwise, if the router and IP address are both set, validate the 
  choice of router and set the block correctly.
- Otherwise, if the router is set, assign an address (in the selected
  block if there is one).
- Check the IP address for availability.

Returns an error if this fails for some reason (an address can't be 
assigned from the requested router/block, or the requested address is
unavailable, or doesn't seem to be an IP address).

If router and IP address are both empty, this will do nothing.  The 
object's check() method should decide whether to allow a null IP address.

=cut

sub ip_check {
  my $self = shift;

  if ( $self->ip_addr eq '0.0.0.0' ) { #ipv6?
    $self->ip_addr('');
  }

  if ( $self->ip_addr
       and !$self->router
       and $self->conf->exists('auto_router') ) {
    # assign a router that matches this IP address
    return $self->check_ip_addr || $self->assign_router;
  }
  if ( my $router = $self->router ) {
    if ( $router->manual_addr ) {
      # Router is set, and it's set to manual addressing, so 
      # clear blocknum and don't tamper with ip_addr.
      $self->addr_block(undef);
    } else {
      my $block = $self->addr_block;
      if ( !$block or !$block->manual_flag ) {
        my $error = $self->assign_ip_addr;
        return $error if $error;
      }
      # otherwise block is set to manual addressing
    }
  }
  return $self->check_ip_addr;
}

=item assign_ip_addr

Set the IP address to a free address in the selected block (C<addr_block>)
or router (C<router>) for this object.  A block or router MUST be selected.
If the object already has an IP address and it is in that block/router's 
address space, it won't be changed.

=cut

sub assign_ip_addr {
  my $self = shift;
  my %opt = @_;

  my @blocks;
  my $na = $self->NetAddr;

  if ( $self->addr_block ) {
    # choose an address in a specific block.
    @blocks = ( $self->addr_block );
  } elsif ( $self->router ) {
    # choose an address from any block on a specific router.
    @blocks = $self->router->auto_addr_block;
  } else {
    # what else should we do, search ALL blocks? that's crazy.
    die "no block or router specified for assign_ip_addr\n";
  }

  my $new_addr;
  my $new_block;
  foreach my $block (@blocks) {
    if ( $self->ip_addr and $block->NetAddr->contains($na) ) {
      return '';
    }
    # don't exit early on assigning a free address--check the rest of 
    # the blocks to see if the current address is in one of them.
    if (!$new_addr) {
      $new_addr = $block->next_free_addr->addr;
      $new_block = $block;
    }
  }
 
  return 'No IP address available on this router' unless $new_addr;

  $self->ip_addr($new_addr);
  $self->addr_block($new_block);
  '';
}

=item assign_router

If the IP address is set, set the router and block accordingly.  If there
is no block containing that address, returns an error.

=cut

sub assign_router {
  my $self = shift;
  return '' unless $self->ip_addr;
  my $na = $self->NetAddr;
  foreach my $router (qsearch('router', {})) {
    foreach my $block ($router->addr_block) {
      if ( $block->NetAddr->contains($na) ) {
        $self->addr_block($block);
        $self->router($router);
        return '';
      }
    }
  }
  return $self->ip_addr . ' is not in an allowed block.';
}

=item check_ip_addr

Validate the IP address.  Returns an empty string if it's correct and 
available (or null), otherwise an error message.

=cut

sub check_ip_addr {
  my $self = shift;
  my $addr = $self->ip_addr;
  return '' if $addr eq '';
  my $na = $self->NetAddr
    or return "Can't parse address '$addr'";
  # if there's a chosen address block, check that the address is in it
  if ( my $block = $self->addr_block ) {
    if ( !$block->NetAddr->contains($na) ) {
      return "Address $addr not in block ".$block->cidr;
    }
  }
  # if the address is in any designated ranges, check that they don't 
  # disallow use
  foreach my $range (FS::addr_range->any_contains($addr)) {
    if ( !$range->allow_use ) {
      return "Address $addr is in ".$range->desc." range ".$range->as_string;
    }
  }
  # check that nobody else is sitting on the address
  # (this returns '' if the address is in use by $self)
  if ( my $dup = $self->is_used($self->ip_addr) ) {
    return "Address $addr in use by $dup";
  }
  '';
}

# sensible defaults
sub addr_block {
  my $self = shift;
  if ( @_ ) {
    my $new = shift;
    if ( defined $new ) {
      die "addr_block() must take an address block"
        unless $new->isa('FS::addr_block');
      $self->blocknum($new->blocknum);
      return $new;
    } else {
      #$new is undef
      $self->blocknum('');
      return undef;
    }
  }
  # could cache this...
  FS::addr_block->by_key($self->blocknum);
}

sub router {
  my $self = shift;
  if ( @_ ) {
    my $new = shift;
    if ( defined $new ) {
      die "router() must take a router"
        unless $new->isa('FS::router');
      $self->routernum($new->routernum);
      return $new;
    } else {
      #$new is undef
      $self->routernum('');
      return undef;
    }
  }
  FS::router->by_key($self->routernum);
}

=item used_addresses [ BLOCK ]

Returns a list of all addresses (in BLOCK, or in all blocks)
that are in use.  If called as an instance method, excludes 
that instance from the search.

=cut

sub used_addresses {
  my $self = shift;
  my $block = shift;
  return ( map { $_->_used_addresses($block, $self) } @subclasses );
}

sub _used_addresses {
  my $class = shift;
  die "$class->_used_addresses not implemented";
}

=item is_used ADDRESS

Returns a string describing what object is using ADDRESS, or 
an empty string if it's not in use.

=cut

sub is_used {
  my $self = shift;
  my $addr = shift;
  for (@subclasses) {
    my $used = $_->_is_used($addr, $self);
    return $used if $used;
  }
  '';
}

sub _is_used {
  my $class = shift;
  die "$class->_is_used not implemented";
}

=back

=head1 BUGS

We can't reliably check for duplicate addresses across tables.  A 
more robust implementation would be to put all assigned IP addresses
in a single table with a unique index.  We do a best-effort check 
anyway, but it has a race condition.

=cut

1; 
