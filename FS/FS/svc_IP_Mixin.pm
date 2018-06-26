package FS::svc_IP_Mixin;
use base 'FS::IP_Mixin';

use strict;
use NEXT;
use Carp qw(croak carp);
use FS::Record qw(qsearchs qsearch dbh);
use FS::Conf;
use FS::router;
use FS::part_svc_router;

=item addr_block

Returns the address block assigned to this service.

=item router

Returns the router assigned to this service, if there is one.

=cut

#addr_block and router methods provided by FS::IP_Mixin

=item NetAddr

Returns the address as a L<NetAddr::IP> object.  Use C<$svc->NetAddr->addr>
to put it into canonical string form.

=cut

sub NetAddr {
  my $self = shift;
  NetAddr::IP->new($self->ip_addr);
}

=item ip_addr

Wrapper for set/get on the IP address field.

=cut

sub ip_addr {
  my $self = shift;
  my $ip_field = $self->table_info->{'ip_field'}
    or return '';
  if ( @_ ) {
    $self->set($ip_field, @_);
  } else {
    $self->get($ip_field);
  }
}

=item allowed_routers

Returns a list of L<FS::router> objects allowed on this service.

=cut

sub allowed_routers {
  my $self = shift;
  my $svcpart = $self->svcnum ? $self->cust_svc->svcpart : $self->svcpart;
  my @r = map { $_->router } 
    qsearch('part_svc_router', { svcpart => $svcpart });

  if ( $self->cust_main ) {
    my $agentnum = $self->cust_main->agentnum;
    return grep { !$_->agentnum or $_->agentnum == $agentnum } @r;
  } else {
    return @r;
  }
}

=item svc_ip_check

Wrapper for C<ip_check> which also checks the validity of the router.

=cut

sub svc_ip_check {
  my $self = shift;
  my $error = $self->ip_check;
  return $error if $error;
  if ( my $router = $self->router ) {
    if ( grep { $_->routernum == $router->routernum } $self->allowed_routers ) {
      return '';
    } else {
      return 'Router '.$router->routername.' not available for this service';
    }
  }
  '';
}

sub _used_addresses {
  my ($class, $block, $exclude_svc) = @_;

  croak "_used_addresses() requires an FS::addr_block parameter"
    unless ref $block && $block->isa('FS::addr_block');

  my $ip_field = $class->table_info->{'ip_field'};
  if ( !$ip_field ) {
    carp "_used_addresses() skipped, no ip_field";
    return;
  }

  my %qsearch = ( $ip_field => { op => '!=', value => '' });
  $qsearch{svcnum} = { op => '!=', value => $exclude_svc->svcnum }
    if ref $exclude_svc && $exclude_svc->svcnum;

  my $block_na = $block->NetAddr;

  my $octets;
  if ($block->ip_netmask >= 24) {
    $octets = 3;
  } elsif ($block->ip_netmask >= 16) {
    $octets = 2;
  } elsif ($block->ip_netmask >= 8) {
    $octets = 1;
  }

  #  e.g.
  # SELECT ip_addr
  # FROM svc_broadband
  # WHERE ip_addr != ''
  #   AND ip_addr != '0e0'
  #   AND ip_addr LIKE '10.0.2.%';
  #
  # For /24, /16 and /8 this approach is fast, even when svc_broadband table
  # contains 650,000+ ip records.  For other allocations, this approach is
  # not speedy, but usable.
  #
  # Note: A use case like this would could greatly benefit from a qsearch()
  #       parameter to bypass FS::Record objects creation and just
  #       return hashrefs from DBI.  200,000 hashrefs are many seconds faster
  #       than 200,000 FS::Record objects
  my %qsearch = (
      table     => $class->table,
      select    => $ip_field,
      hashref   => \%qsearch,
      extra_sql => " AND $ip_field != '0e0' ",
  );
  if ( $octets ) {
    my $block_str = join('.', (split(/\D/, $block_na->first))[0..$octets-1]);
    $qsearch{extra_sql} .= " AND $ip_field LIKE ".dbh->quote("${block_str}.%");
  }

  if ( $block->ip_netmask % 8 ) {
    # Some addresses returned by qsearch may be outside the network block,
    # so each ip address is tested to be in the block before it's returned.
    return
      grep { $block_na->contains( NetAddr::IP->new( $_ ) ) }
      map { $_->$ip_field }
      qsearch( \%qsearch );
  }

  return
    map { $_->$ip_field }
    qsearch( \%qsearch );
}

sub _is_used {
  my ($class, $addr, $exclude) = @_;
  my $ip_field = $class->table_info->{'ip_field'}
    or return '';

  my $svc = qsearchs($class->table, { $ip_field => $addr })
    or return '';

  return '' if ( ref $exclude and $exclude->svcnum == $svc->svcnum );

  my $cust_svc = $svc->cust_svc;
  if ( $cust_svc ) {
    my @label = $cust_svc->label;
    # "svc_foo 1234 (Service Desc)"
    # this should be enough to identify it without leaking customer
    # names across agents
    "$label[2] $label[3] ($label[0])";
  } else {
    join(' ', $class->table, $svc->svcnum, '(unlinked service)');
  }
}

=item attached_router

Returns the L<FS::router> attached via this service (as opposed to the one
this service is connected through), that is, a router whose "svcnum" field
equals this service's primary key.

If the 'router_routernum' pseudo-field is set, returns that router instead.

=cut

sub attached_router {
  my $self = shift;
  if ( length($self->get('router_routernum') )) {
    return FS::router->by_key($self->router_routernum);
  } else {
    qsearchs('router', { 'svcnum' => $self->svcnum });
  }
}

=item attached_block

Returns the address block (L<FS::addr_block>) assigned to the attached_router,
if there is one.

If the 'router_blocknum' pseudo-field is set, returns that block instead.

=cut

sub attached_block {
  my $self = shift;
  if ( length($self->get('router_blocknum')) ) {
    return FS::addr_block->by_key($self->router_blocknum);
  } else {
    my $router = $self->attached_router or return '';
    my ($block) = $router->addr_block;
    return $block || '';
  }
}

=item radius_check

Returns nothing.

=cut

sub radius_check { }

=item radius_reply

Returns RADIUS reply items that are relevant across all exports and 
necessary for the IP address configuration of the service.  Currently, that
means "Framed-Route" if there's an attached router.

=cut

sub radius_reply {
  my $self = shift;

  my %reply = ();

  if ( my $block = $self->attached_block ) {
    # block routed over dynamic IP: "192.168.100.0/29 0.0.0.0 1"
    # or
    # block routed over fixed IP: "192.168.100.0/29 192.168.100.1 1"
    # (the "1" at the end is the route metric)
    $reply{'Framed-Route'} = $block->cidr . ' ' .
                             ($self->ip_addr || '0.0.0.0') . ' 1';
  }

  $reply{'Motorola-Canopy-Gateway'} = $self->addr_block->ip_gateway
    if FS::Conf->new->exists('radius-canopy') && $self->addr_block;

  %reply;
}

sub replace_check {
  my ($new, $old) = @_;
  # this modifies $old, not $new, which is a slight abuse of replace_check,
  # but there's no way to ensure that replace_old gets called...
  #
  # ensure that router_routernum and router_blocknum are set to their
  # current values, so that exports remember the service's attached router 
  # and block even after they've been replaced
  my $router = $old->attached_router;
  my $block = $old->attached_block;
  $old->set('router_routernum', $router ? $router->routernum : 0);
  $old->set('router_blocknum', $block ? $block->blocknum : 0);
  my $err_or_ref = $new->NEXT::replace_check($old) || '';
  # because NEXT::replace_check($old) ends up trying to AUTOLOAD replace_check
  # which is dumb, but easily worked around
  ref($err_or_ref) ? '' : $err_or_ref;
}

1;
