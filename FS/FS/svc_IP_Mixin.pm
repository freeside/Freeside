package FS::svc_IP_Mixin;

use strict;
use base 'FS::IP_Mixin';
use FS::Record qw(qsearchs qsearch);

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
  $hash{'blocknum'} = $block->blocknum if $block;
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

1;
