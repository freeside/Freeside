package FS::part_export::forward_shellcommands;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'',
               },
  'userdel'  => { label=>'Delete command',
                  default=>'',
                },
  'usermod'  => { label=>'Modify command',
                  default=>'',
                },
;

%info = (
  'svc'     => 'svc_forward',
  'desc'    => 'Run remote commands via SSH, for forwards',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for forwards.  You will need to
<a href="../docs/ssh.html">setup SSH for unattended operation</a>.
<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="text vpopmail maintenance" onClick='
      this.form.useradd.value = "[ -d /home/vpopmail/domains/$domain/$username ] && { echo \"$destination\" > /home/vpopmail/domains/$domain/$username/.qmail; chown vpopmail:vchkpw /home/vpopmail/domains/$domain/$username/.qmail; }";
      this.form.userdel.value = "rm /home/vpopmail/domains/$domain/$username/.qmail";
      this.form.usermod.value = "mv /home/vpopmail/domains/$old_domain/$old_username/.qmail /home/vpopmail/domains/$new_domain/$new_username; [ \"$old_destination\" != \"$new_destination\" ] && { echo \"$new_destination\" > /home/vpopmail/domains/$new_domain/$new_username/.qmail; chown vpopmail:vchkpw /home/vpopmail/domains/$new_domain/$new_username/.qmail; }";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="ISPMan CLI" onClick='
      this.form.useradd.value = "";
      this.form.userdel.value = "";
      this.form.usermod.value = "";
    '>
</UL>
The following variables are available for interpolation (prefixed with
<code>new_</code> or <code>old_</code> for replace operations):
<UL>
  <LI><code>$username</code>
  <LI><code>$domain</code>
  <LI><code>$destination</code> - forward destination
  <LI>All other fields in <a href="../docs/schema.html#svc_forward">svc_forward</a> are also available.
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

sub _export_command {
  my ( $self, $action, $svc_forward ) = (shift, shift, shift);
  my $command = $self->option($action);

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_forward->getfield($_) foreach $svc_forward->fields;
  }

  my $svc_acct = $svc_forward->srcsvc_acct;
  $username = $svc_acct->username;
  $domain = $svc_acct->domain;
  if ($svc_forward->dstsvc_acct) {
    $destination = $svc_forward->dstsvc_acct->email;
  } else {
    $destination = $svc_forward->dst;
  }

  #done setting variables for the command

  $self->shellcommands_queue( $svc_forward->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  
  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }

  my $old_svc_acct = $old->srcsvc_acct;
  $old_username = $old_svc_acct->username;
  $old_domain = $old_svc_acct->domain;
  if ($old->dstsvc_acct) {
    $old_destination = $old->dstsvc_acct->email;
  } else {
    $old_destination = $old->dst;
  }

  my $new_svc_acct = $new->srcsvc_acct;
  $new_username = $new_svc_acct->username;
  $new_domain = $new_svc_acct->domain;
  if ($new->dstsvc) {
    $new_destination = $new->dstsvc_acct->email;
  } else {
    $new_destination = $new->dst;
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
    'job'    => "FS::part_export::forward_shellcommands::ssh_cmd",
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

1;

