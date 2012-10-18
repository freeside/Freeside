package FS::part_export::broadband_shellcommands;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user'          => { label   => 'Remote username',
                       default => 'freeside' },
  'insert'        => { label   => 'Insert command',
                       default => 'php provision.php --mac=$mac_addr --plan=$plan_id --account=active',
                     },
  'delete'        => { label   => 'Delete command',
                       default  => '',
                     },
  'replace'       => { label   => 'Modification command',
                       default => '',
                     },
  'suspend'       => { label   => 'Suspension command',
                       default => 'php provision.php --mac=$mac_addr --plan=$plan_id --account=suspend',
                     },
  'unsuspend'     => { label   => 'Unsuspension command',
                       default => '',
                     },
  'uppercase_mac' => { label   => 'Force MACs to uppercase', 
                       type   => 'checkbox',
                     }
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Run remote commands via SSH, for svc_broadband services',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for broadband services.
<BR><BR>
All fields in svc_broadband are available for interpolation (prefixed with
<code>new_</code> or <code>old_</code> for replace operations).
END
);


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

  #set variables for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
  }

  $mac_addr = uc $mac_addr
    if $self->option('uppercase_mac');

  #done setting variables for the command

  $self->shellcommands_queue( $svc_broadband->svcnum,
    user    => $self->option('user')||'root',
    host    => $self->machine,
    command => eval(qq("$command")),
  );
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('replace');

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }

  if ( $self->option('uppercase_mac') ) {
    $old_mac_addr = uc $old_mac_addr;
    $new_mac_addr = uc $new_mac_addr;
  }

  #done setting variables for the command

  $self->shellcommands_queue( $new->svcnum,
    user    => $self->option('user')||'root',
    host    => $self->machine,
    command => eval(qq("$command")),
  );
}

#a good idea to queue anything that could fail or take any time
sub shellcommands_queue {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::broadband_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::OpenSSH;
  my $opt = { @_ };
  my $ssh = Net::OpenSSH->new($opt->{'user'}.'@'.$opt->{'host'});
  die "Couldn't establish SSH connection: ". $ssh->error if $ssh->error;
  my ($output, $errput) = $ssh->capture2($opt->{'command'});
  die "Error running SSH command: ". $ssh->error if $ssh->error;
  die $errput if $errput;
  die $output if $output;
  '';
}

