package FS::part_export::domain_shellcommands;

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
  'svc'     => 'svc_domain',
  'desc'    => 'Run remote commands via SSH, for domains (qmail, ISPMan).',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for domains.  You will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.
<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="qmail catchall .qmail-domain-default maintenance" onClick='
      this.form.useradd.value = "[ \"$uid\" -a \"$gid\" -a \"$dir\" -a \"$qdomain\" ] && [ -e $dir/.qmail-$qdomain-default ] || { touch $dir/.qmail-$qdomain-default; chown $uid:$gid $dir/.qmail-$qdomain-default; }";
      this.form.userdel.value = "";
      this.form.usermod.value = "";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="ISPMan CLI" onClick='
      this.form.useradd.value = "/usr/local/ispman/bin/ispman.addDomain -d $domain changeme";
      this.form.userdel.value = "/usr/local/ispman/bin/ispman.deleteDomain -d $domain";
      this.form.usermod.value = "";
    '>
</UL>
The following variables are available for interpolation (prefixed with <code>new_</code> or <code>old_</code> for replace operations):
<UL>
  <LI><code>$domain</code>
  <LI><code>$qdomain</code> - domain with periods replaced by colons
  <LI><code>$uid</code> - of catchall account
  <LI><code>$gid</code> - of catchall account
  <LI><code>$dir</code> - home directory of catchall account
  <LI>All other fields in
    <a href="../docs/schema.html#svc_domain">svc_domain</a> are also available.
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
  my ( $self, $action, $svc_domain) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;

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
    no strict 'refs';
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

  { 
    no strict 'refs';

    if ( $old->catchall ) {
      my $svc_acct = $old->catchall_svc_acct;
      ${"old_$_"} = $svc_acct->getfield($_) foreach qw(uid gid dir);
    } else {
      ${"old_$_"} = '' foreach qw(uid gid dir);
    }
    if ( $new->catchall ) {
      my $svc_acct = $new->catchall_svc_acct;
      ${"new_$_"} = $svc_acct->getfield($_) foreach qw(uid gid dir);
    } else {
      ${"new_$_"} = '' foreach qw(uid gid dir);
    }

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

