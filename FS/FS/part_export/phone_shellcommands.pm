package FS::part_export::phone_shellcommands;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use String::ShellQuote;
use FS::part_export;

@ISA = qw(FS::part_export);

#TODO
#- modify command (get something from freepbx for changing PINs)
#- suspension/unsuspension

tie my %options, 'Tie::IxHash',
  'user'      => { label=>'Remote username', default=>'root', },
  'useradd'   => { label=>'Insert command', }, 
  'userdel'   => { label=>'Delete command', }, 
  'usermod'   => { label=>'Modify command', }, 
  'suspend'   => { label=>'Suspension command', }, 
  'unsuspend' => { label=>'Unsuspension command', }, 
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Run remote commands via SSH, for phone numbers',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for phone numbers.  You will need to
<a href="../docs/ssh.html">setup SSH for unattended operation</a>.
<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="FreePBX (build_exten CLI module needed)" onClick='
      this.form.user.value = "root";
      this.form.useradd.value = "build_exten.php --create --exten $phonenum --directdid 1$phonenum --sip-secret $sip_password --name $cust_name --vm-password $pin && /usr/share/asterisk/bin/module_admin reload";
      this.form.userdel.value = "build_exten.php --delete --exten $phonenum && /usr/share/asterisk/bin/module_admin reload";
      this.form.usermod.value = "";
      this.form.suspend.value = "";
      this.form.unsuspend.value = "";
    '> (Important note: Reduce freeside-queued "max_kids" to 1 when using FreePBX integration)
  </UL>

The following variables are available for interpolation (prefixed with new_ or
old_ for replace operations):
<UL>
  <LI><code>$countrycode</code> - Country code
  <LI><code>$phonenum</code> - Phone number
  <LI><code>$sip_password</code> - SIP secret (quoted for the shell)
  <LI><code>$pin</code> - Personal identification number
  <LI><code>$cust_name</code> - Customer name (quoted for the shell)
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
  my ( $self, $action, $svc_phone) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_phone->getfield($_) foreach $svc_phone->fields;
  }
  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $cust_name = $cust_pkg ? $cust_pkg->cust_main->name : '';
  $cust_name = shell_quote $cust_name;
  my $sip_password = shell_quote $svc_phone->sip_password;
  #done setting variables for the command

  $self->shellcommands_queue( $svc_phone->svcnum,
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

  my $cust_pkg = $new->cust_svc->cust_pkg;
  my $new_cust_name = $cust_pkg ? $cust_pkg->cust_main->name : '';
  $new_cust_name = shell_quote $new_cust_name;
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
    'job'    => "FS::part_export::phone_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.08';
  &Net::SSH::ssh_cmd( { @_ } );
}

