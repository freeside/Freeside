package FS::part_export::router;

=head1 FS::part_export::router

This export connects to a router and transmits commands via telnet or SSH.
It requires the following custom router fields:

=over 4

=item admin_address - IP address (or hostname) to connect

=item admin_user - username for admin access

=item admin_password - password for admin access

=back

The export itself needs the following options:

=over 4

=item insert, replace, delete - command strings (to be interpolated)

=item Prompt - prompt string to expect from router after successful login

=item Timeout - time to wait for prompt string

=back

(Prompt and Timeout are required only for telnet connections.)

=cut

use vars qw(@ISA @saltset);
use String::ShellQuote;
use FS::part_export;

@ISA = qw(FS::part_export);

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

sub rebless { shift; }

sub _export_insert {
  my($self) = shift;
  $self->_export_command('insert', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('delete', @_);
}

sub _export_suspend {
  my($self) = shift;
  $self->_export_command('suspend', @_);
}

sub _export_unsuspend {
  my($self) = shift;
  $self->_export_command('unsuspend', @_);
}

sub _export_command {
  my ( $self, $action, $svc_broadband) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;

  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
  }
  # fetch router info
  my $router = $svc_broadband->addr_block->router;
  my %r;
  $r{$_} = $router->getfield($_) foreach $router->virtual_fields;
  #warn qq("$command");
  #warn eval(qq("$command"));

  warn "admin_address: '$r{admin_address}'";

  if ($r{admin_address} ne '') {
    $self->router_queue( $svc_broadband->svcnum, $self->option('protocol'),
      user         => $r{admin_user},
      password     => $r{admin_password},
      host         => $r{admin_address},
      Timeout      => $self->option('Timeout'),
      Prompt       => $self->option('Prompt'),
      command      => eval(qq("$command")),
    );
  } else {
    return '';
  }
}

sub _export_replace {

  # We don't handle the case of a svc_broadband moving between routers.
  # If you want to do that, reprovision the service.

  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('replace');
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }

  my $router = $new->addr_block->router;
  my %r;
  $r{$_} = $router->getfield($_) foreach $router->virtual_fields;

  if ($r{admin_address} ne '') {
    $self->router_queue( $new->svcnum, $self->option('protocol'),
      user         => $r{admin_user},
      password     => $r{admin_password},
      host         => $r{admin_address},
      Timeout      => $self->option('Timeout'),
      Prompt       => $self->option('Prompt'),
      command      => eval(qq("$command")),
    );
  } else {
    return '';
  }
}

#a good idea to queue anything that could fail or take any time
sub router_queue {
  #warn join ':', @_;
  my( $self, $svcnum, $protocol ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
  };
  $queue->job ("FS::part_export::router::".$protocol."_cmd");
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.08';
  &Net::SSH::ssh_cmd( { @_ } );
}

sub telnet_cmd {
  use Net::Telnet;

  warn join(', ', @_);

  my %arg = @_;

  my $t = new Net::Telnet (Timeout => $arg{Timeout},
                           Prompt  => $arg{Prompt});
  $t->open($arg{host});
  $t->login($arg{user}, $arg{password});
  my @error = $t->cmd($arg{command});
  die @error if (grep /^ERROR/, @error);
}

#sub router_insert { #subroutine, not method
#}
#sub router_replace { #subroutine, not method
#}
#sub router_delete { #subroutine, not method
#}

