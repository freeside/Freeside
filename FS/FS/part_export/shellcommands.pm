package FS::part_export::shellcommands;

use vars qw(@ISA %info @saltset);
use Tie::IxHash;
use String::ShellQuote;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'useradd -c $finger -d $dir -m -s $shell -u $uid -p $crypt_password $username'
                #default=>'cp -pr /etc/skel $dir; chown -R $uid.$gid $dir'
               },
  'useradd_stdin' => { label=>'Insert command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'userdel' => { label=>'Delete command',
                 default=>'userdel -r $username',
                 #default=>'rm -rf $dir',
               },
  'userdel_stdin' => { label=>'Delete command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'usermod' => { label=>'Modify command',
                 default=>'usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -p $new_crypt_password $old_username',
                #default=>'[ -d $old_dir ] && mv $old_dir $new_dir || ( '.
                 #  'chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; '.
                 #  'find . -depth -print | cpio -pdm $new_dir; '.
                 #  'chmod u-t $new_dir; chown -R $uid.$gid $new_dir; '.
                 #  'rm -rf $old_dir'.
                 #')'
               },
  'usermod_stdin' => { label=>'Modify command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'usermod_pwonly' => { label=>'Disallow username changes',
                        type =>'checkbox',
                      },
  'suspend' => { label=>'Suspension command',
                 default=>'usermod -L $username',
               },
  'suspend_stdin' => { label=>'Suspension command STDIN',
                       default=>'',
                     },
  'unsuspend' => { label=>'Unsuspension command',
                   default=>'usermod -U $username',
                 },
  'unsuspend_stdin' => { label=>'Unsuspension command STDIN',
                         default=>'',
                       },
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     =>
    'Real-time export via remote SSH (i.e. useradd, userdel, etc.)',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes' => <<'END'
Run remote commands via SSH.  Usernames are considered unique (also see
shellcommands_withdomain).  You probably want this if the commands you are
running will not accept a domain as a parameter.  You will need to
<a href="../docs/ssh.html">setup SSH for unattended operation</a>.

<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="Linux" onClick='
      this.form.useradd.value = "useradd -c $finger -d $dir -m -s $shell -u $uid -p $crypt_password $username";
      this.form.useradd_stdin.value = "";
      this.form.userdel.value = "userdel -r $username";
      this.form.userdel_stdin.value="";
      this.form.usermod.value = "usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -p $new_crypt_password $old_username";
      this.form.usermod_stdin.value = "";
      this.form.suspend.value = "usermod -L $username";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "usermod -U $username";
      this.form.unsuspend_stdin.value="";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="FreeBSD before 5.3" onClick='
      this.form.useradd.value = "lockf /etc/passwd.lock pw useradd $username -d $dir -m -s $shell -u $uid -g $gid -c $finger -h 0";
      this.form.useradd_stdin.value = "$_password\n";
      this.form.userdel.value = "lockf /etc/passwd.lock pw userdel $username -r"; this.form.userdel_stdin.value="";
      this.form.usermod.value = "lockf /etc/passwd.lock pw usermod $old_username -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -c $new_finger -h 0";
      this.form.usermod_stdin.value = "$new__password\n"; this.form.suspend.value = "lockf /etc/passwd.lock pw lock $username";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "lockf /etc/passwd.lock pw unlock $username"; this.form.unsuspend_stdin.value="";
    '>
    Note: On FreeBSD versions before 5.3, due to deficient locking in pw(1),
    you must disable the chpass(1), chsh(1), chfn(1), passwd(1), and vipw(1)
    commands, or replace them with wrappers that prepend
    "lockf /etc/passwd.lock".  Alternatively, apply the patch in
    <A HREF="http://www.freebsd.org/cgi/query-pr.cgi?pr=23501">FreeBSD PR#23501</A>
    and use the "FreeBSD 5.3 or later" button below.
  <LI>
    <INPUT TYPE="button" VALUE="FreeBSD 5.3 or later" onClick='
      this.form.useradd.value = "pw useradd $username -d $dir -m -s $shell -u $uid -g $gid -c $finger -h 0";
      this.form.useradd_stdin.value = "$_password\n";
      this.form.userdel.value = "pw userdel $username -r";
      this.form.userdel_stdin.value="";
      this.form.usermod.value = "pw usermod $old_username -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -c $new_finger -h 0";
      this.form.usermod_stdin.value = "$new__password\n";
      this.form.suspend.value = "pw lock $username";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "pw unlock $username";
      this.form.unsuspend_stdin.value="";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="NetBSD/OpenBSD" onClick='
      this.form.useradd.value = "useradd -c $finger -d $dir -m -s $shell -u $uid -p $crypt_password $username";
      this.form.useradd_stdin.value = "";
      this.form.userdel.value = "userdel -r $username";
      this.form.userdel_stdin.value="";
      this.form.usermod.value = "usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -p $new_crypt_password $old_username";
      this.form.usermod_stdin.value = "";
      this.form.suspend.value = "";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "";
      this.form.unsuspend_stdin.value="";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="Just maintain directories (use with sysvshell or bsdshell)" onClick='
      this.form.useradd.value = "cp -pr /etc/skel $dir; chown -R $uid.$gid $dir"; this.form.useradd_stdin.value = "";
      this.form.usermod.value = "[ -d $old_dir ] && mv $old_dir $new_dir || ( chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; find . -depth -print | cpio -pdm $new_dir; chmod u-t $new_dir; chown -R $new_uid.$new_gid $new_dir; rm -rf $old_dir )";
      this.form.usermod_stdin.value = "";
      this.form.userdel.value = "rm -rf $dir";
      this.form.userdel_stdin.value="";
      this.form.suspend.value = "";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "";
      this.form.unsuspend_stdin.value="";
    '>
</UL>

The following variables are available for interpolation (prefixed with new_ or
old_ for replace operations):
<UL>
  <LI><code>$username</code>
  <LI><code>$_password</code>
  <LI><code>$quoted_password</code> - unencrypted password quoted for the shell
  <LI><code>$crypt_password</code> - encrypted password
  <LI><code>$uid</code>
  <LI><code>$gid</code>
  <LI><code>$finger</code> - GECOS, already quoted for the shell (do not add additional quotes)
  <LI><code>$dir</code> - home directory
  <LI><code>$shell</code>
  <LI><code>$quota</code>
  <LI>All other fields in <a href="../docs/schema.html#svc_acct">svc_acct</a> are also available.
</UL>
END
);

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

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
  my ( $self, $action, $svc_acct) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;
  my $stdin = $self->option($action."_stdin");

  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;

    my $count = 1;
    foreach my $acct_snarf ( $svc_acct->acct_snarf ) {
      ${"snarf_$_$count"} = shell_quote( $acct_snarf->get($_) )
        foreach qw( machine username _password );
      $count++;
    }
  }

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    $email = ( grep { $_ ne 'POST' } $cust_pkg->cust_main->invoicing_list )[0];
  } else {
    $email = '';
  }

  $finger = shell_quote $finger;
  $quoted_password = shell_quote $_password;
  $domain = $svc_acct->domain;

  #eventually should check a "password-encoding" field
  if ( length($svc_acct->_password) == 13
       || $svc_acct->_password =~ /^\$(1|2a?)\$/ ) {
    $crypt_password = shell_quote $svc_acct->_password;
  } else {
    $crypt_password = crypt(
      $svc_acct->_password,
      $saltset[int(rand(64))].$saltset[int(rand(64))]
    );
  }

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
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }
  $new_finger = shell_quote $new_finger;
  $quoted_new__password = shell_quote $new__password; #old, wrong?
  $new_quoted_password = shell_quote $new__password; #new, better?
  $old_domain = $old->domain;
  $new_domain = $new->domain;

  #eventuall should check a "password-encoding" field
  if ( length($new->_password) == 13
       || $new->_password =~ /^\$(1|2a?)\$/ ) {
    $new_crypt_password = shell_quote $new->_password;
  } else {
    $new_crypt_password =
      crypt( $new->_password, $saltset[int(rand(64))].$saltset[int(rand(64))]
    );
  }

  if ( $self->option('usermod_pwonly') ) {
    my $error = '';
    if ( $old_username ne $new_username ) {
      $error ||= "can't change username";
    }
    if ( $old_domain ne $new_domain ) {
      $error ||= "can't change domain";
    }
    if ( $old_uid != $new_uid ) {
      $error ||= "can't change uid";
    }
    if ( $old_dir ne $new_dir ) {
      $error ||= "can't change dir";
    }
    return $error. ' ('. $self->exporttype. ' to '. $self->machine. ')'
      if $error;
  }
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

