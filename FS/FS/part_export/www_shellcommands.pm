package FS::part_export::www_shellcommands;

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
  my ( $self, $action, $svc_www) = (shift, shift, shift);
  my $command = $self->option($action);

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_www->getfield($_) foreach $svc_www->fields;
  }
  my $domain_record = $svc_www->domain_record; # or die ?
  my $zone = $domain_record->zone; # or die ?
  my $svc_acct = $svc_www->svc_acct; # or die ?
  my $username = $svc_acct->username;
  my $homedir = $svc_acct->dir; # or die ?

  #done setting variables for the command

  $self->shellcommands_queue( $svc_www->svcnum,
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
  my $old_domain_record = $old->domain_record; # or die ?
  my $old_zone = $old_domain_record->reczone; # or die ?
  unless ( $old_zone =~ /\.$/ ) {
    my $old_svc_domain = $old_domain_record->svc_domain; # or die ?
    $old_zone .= '.'. $old_svc_domain->domain;
  }

  my $old_svc_acct = $old->svc_acct; # or die ?
  my $old_username = $old_svc_acct->username;
  my $old_homedir = $old_svc_acct->dir; # or die ?

  my $new_domain_record = $new->domain_record; # or die ?
  my $new_zone = $new_domain_record->reczone; # or die ?
  unless ( $new_zone =~ /\.$/ ) {
    my $new_svc_domain = $new_domain_record->svc_domain; # or die ?
    $new_zone .= '.'. $new_svc_domain->domain;
  }

  my $new_svc_acct = $new->svc_acct; # or die ?
  my $new_username = $new_svc_acct->username;
  my $new_homedir = $new_svc_acct->dir; # or die ?

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
    'job'    => "FS::part_export::www_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.08';
  &Net::SSH::ssh_cmd( { @_ } );
}

#sub shellcommands_insert { #subroutine, not method
#}
#sub shellcommands_replace { #subroutine, not method
#}
#sub shellcommands_delete { #subroutine, not method
#}

