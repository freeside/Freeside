package FS::part_export::shellcommands;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self) = shift;
  $self->_export_command('useradd', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('userdel', @_);
}

sub _export_command {
  my ( $self, $action, $svc_acct) = (shift, shift, shift);
  my $command = $self->option($action);
  no strict 'refs';
  ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;
  $self->shellcommands_queue(
    $self->options('user')||'root'. "\@". $self->options('machine'),
    eval(qq("$command"))
  );
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  no strict 'refs';
  ${"old_$_"} = $old->getfield($_) foreach $old->fields;
  ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  $self->shellcommands_queue(
    $self->options('user')||'root'. "\@". $self->options('machine'),
    eval(qq("$command"))
  );
}

#a good idea to queue anything that could fail or take any time
sub shellcommands_queue {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "Net::SSH::ssh_cmd", #freeside-queued pre-uses...
  };
  $queue->insert( @_ );
}

#sub shellcommands_insert { #subroutine, not method
#}
#sub shellcommands_replace { #subroutine, not method
#}
#sub shellcommands_delete { #subroutine, not method
#}

