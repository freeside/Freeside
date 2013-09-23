package FS::svc_IP_Mixin;

use strict;
use base 'FS::IP_Mixin';
use FS::Record qw(qsearchs qsearch);
use NEXT;

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
    if ( grep { $_->routernum eq $router->routernum } $self->allowed_routers ) {
      return '';
    } else {
      return 'Router '.$router->routername.' not available for this service';
    }
  }
  '';
}

sub _used_addresses {
  my ($class, $block, $exclude) = @_;
  my $ip_field = $class->table_info->{'ip_field'}
    or return ();
  # if the service doesn't have an ip_field, then it has no IP addresses 
  # in use, yes? 

  my %hash = ( $ip_field => { op => '!=', value => '' } );
  #$hash{'blocknum'} = $block->blocknum if $block;
  $hash{'svcnum'} = { op => '!=', value => $exclude->svcnum } if ref $exclude;
  map { $_->NetAddr->addr } qsearch($class->table, \%hash);
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
  my %reply;
  my ($block) = $self->attached_block;
  if ( $block ) {
    # block routed over dynamic IP: "192.168.100.0/29 0.0.0.0 1"
    # or
    # block routed over fixed IP: "192.168.100.0/29 192.168.100.1 1"
    # (the "1" at the end is the route metric)
    $reply{'Framed-Route'} =
    $block->cidr . ' ' .
    ($self->ip_addr || '0.0.0.0') . ' 1';
  }
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
