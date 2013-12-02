package FS::part_export::external_shellcommands;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use String::ShellQuote;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user'      => { label=>'Remote username', default=>'root', },
  'useradd'   => { label=>'Insert command', }, 
  'userdel'   => { label=>'Delete command', }, 
  'usermod'   => { label=>'Modify command', }, 
  'suspend'   => { label=>'Suspension command', }, 
  'unsuspend' => { label=>'Unsuspension command', }, 
;

%info = (
  'svc'     => 'svc_external',
  'desc'    => 'Run remote commands via SSH, for external Service',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for .  You will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.
<BR>
The following variables are available for interpolation (prefixed with new_ or
old_ for replace operations):
<UL>
  <LI><code>$id</code>
  <LI><code>$title</code>
  <LI><code>$pkgnum</code>
  <LI><code>$custnum</code>
</UL>
END
);

sub rebless { shift; }

sub _export_insert {
  my($self) = shift;
  $self->_export_command('useradd', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('userdel', @_);
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
  my ( $self, $action, $svc_external) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_external->getfield($_) foreach $svc_external->fields;
  }
  my $cust_pkg = $svc_external->cust_svc->cust_pkg;
  my $cust_name = $cust_pkg ? $cust_pkg->cust_main->name : '';
  my $title = shell_quote $svc_external->title;
  my $pkgnum = shell_quote $cust_pkg->pkgnum;
  my $custnum = shell_quote $cust_pkg->custnum;
  #done setting variables for the command

  $self->shellcommands_queue( $svc_external->svcnum,
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

  my $new_cust_pkg = $new->cust_svc->cust_pkg;
  my $old_cust_pkg = $old->cust_svc->cust_pkg;
  $new_title = shell_quote $new->title;
  $old_title = shell_quote $old->title;
  my $new_cust_name = $new_cust_pkg ? $new_cust_pkg->cust_main->name : '';
  my $old_cust_name = $old_cust_pkg ? $old_cust_pkg->cust_main->name : '';
  my $new_pkgnum = shell_quote $new_cust_pkg->pkgnum;
  my $new_custnum = shell_quote $new_cust_pkg->custnum;
  my $old_pkgnum = shell_quote $old_cust_pkg->pkgnum;
  my $old_custnum = shell_quote $old_cust_pkg->custnum;
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
    'job'    => "FS::part_export::external_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.08';
  &Net::SSH::ssh_cmd( { @_ } );
}
