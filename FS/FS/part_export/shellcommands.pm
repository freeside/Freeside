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
  my $stdin = $self->option($action."_stdin");
  no strict 'refs';
  ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;
  $self->shellcommands_queue( $svc_acct->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
    stdin_string => eval(qq("$stdin")),
  );
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  my $stdin = $self->option('usermod_stdin');
  no strict 'refs';
  ${"old_$_"} = $old->getfield($_) foreach $old->fields;
  ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  $self->shellcommands_queue( $new->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
    stdin_string => eval(qq("$stdin")),
  );
}

#a good idea to queue anything that could fail or take any time
sub shellcommands_queue {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.06';
  &Net::SSH::ssh_cmd( { @_ } );
}

#sub shellcommands_insert { #subroutine, not method
#}
#sub shellcommands_replace { #subroutine, not method
#}
#sub shellcommands_delete { #subroutine, not method
#}

