package FS::part_export::domain_shellcommands;

use strict;
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
  my ( $self, $action, $svc_domain) = (shift, shift, shift);
  my $command = $self->option($action);

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_domain->getfield($_) foreach $svc_domain->fields;
  }
  ( $qdomain = $domain ) =~ s/\./:/g; #see dot-qmail(5): EXTENSION ADDRESSES

  if ( $svc_domain->catchall ) {
    no strict 'refs';
    my $svc_acct = $svc_domain->catchall_svc_acct;
    ${$_} = $svc_acct->getfield($_) foreach qw(uid gid dir);
  } else {
    ${$_} = '' foreach qw(uid gid dir);
  }

  #done setting variables for the command

  $self->shellcommands_queue( $svc_domain->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
  );
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  
  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }
  ( $old_qdomain = $old_domain ) =~ s/\./:/g; #see dot-qmail(5): EXTENSION ADDRESSES
  ( $new_qdomain = $new_domain ) =~ s/\./:/g; #see dot-qmail(5): EXTENSION ADDRESSES

  if ( $old->catchall ) {
    no strict 'refs';
    my $svc_acct = $old->catchall_svc_acct;
    ${"old_$_"} = $svc_acct->getfield($_) foreach qw(uid gid dir);
  } else {
    ${"old_$_"} = '' foreach qw(uid gid dir);
  }
  if ( $new->catchall ) {
    no strict 'refs';
    my $svc_acct = $new->catchall_svc_acct;
    ${"new_$_"} = $svc_acct->getfield($_) foreach qw(uid gid dir);
  } else {
    ${"new_$_"} = '' foreach qw(uid gid dir);
  }

  #done setting variables for the command

  $self->shellcommands_queue( $new->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
  );
}

#a good idea to queue anything that could fail or take any time
sub shellcommands_queue {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::domain_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.07';
  &Net::SSH::ssh_cmd( { @_ } );
}

#sub shellcommands_insert { #subroutine, not method
#}
#sub shellcommands_replace { #subroutine, not method
#}
#sub shellcommands_delete { #subroutine, not method
#}

