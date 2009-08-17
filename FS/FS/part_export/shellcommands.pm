package FS::part_export::shellcommands;

use vars qw(@ISA %info);
use Tie::IxHash;
use String::ShellQuote;
use FS::part_export;
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'useradd -c $finger -d $dir -m -s $shell -u $uid -p $crypt_password $username'
                #default=>'cp -pr /etc/skel $dir; chown -R $uid.$gid $dir'
               },
  'useradd_no_queue' => { label=>'Run immediately',
                          type => 'checkbox',
                        },
  'useradd_stdin' => { label=>'Insert command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'userdel' => { label=>'Delete command',
                 default=>'userdel -r $username',
                 #default=>'rm -rf $dir',
               },
  'userdel_no_queue' => { label=>'Run immediately',
                          type =>'checkbox',
                        },
  'userdel_stdin' => { label=>'Delete command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'usermod' => { label=>'Modify command',
                 default=>'usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -g $new_gid -p $new_crypt_password $old_username',
                #default=>'[ -d $old_dir ] && mv $old_dir $new_dir || ( '.
                 #  'chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; '.
                 #  'find . -depth -print | cpio -pdm $new_dir; '.
                 #  'chmod u-t $new_dir; chown -R $uid.$gid $new_dir; '.
                 #  'rm -rf $old_dir'.
                 #')'
               },
  'usermod_no_queue' => { label=>'Run immediately',
                          type =>'checkbox',
                        },
  'usermod_stdin' => { label=>'Modify command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'usermod_pwonly' => { label=>'Disallow username, domain, uid, gid, and dir changes', #and RADIUS group changes',
                        type =>'checkbox',
                      },
  'usermod_nousername' => { label=>'Disallow just username changes',
                            type =>'checkbox',
                          },
  'suspend' => { label=>'Suspension command',
                 default=>'usermod -L $username',
               },
  'suspend_no_queue' => { label=>'Run immediately',
                          type =>'checkbox',
                        },
  'suspend_stdin' => { label=>'Suspension command STDIN',
                       default=>'',
                     },
  'unsuspend' => { label=>'Unsuspension command',
                   default=>'usermod -U $username',
                 },
  'unsuspend_no_queue' => { label=>'Run immediately',
                            type =>'checkbox',
                          },
  'unsuspend_stdin' => { label=>'Unsuspension command STDIN',
                         default=>'',
                       },
  'crypt' => { label   => 'Default password encryption',
               type=>'select', options=>[qw(crypt md5)],
               default => 'crypt',
             },
  'groups_susp_reason' => { label =>
                             'Radius group mapping to reason (via template user)',
			    type  => 'textarea',
			  },
#  'no_queue' => { label => 'Run command immediately',
#                   type  => 'checkbox',
#                },
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
      this.form.usermod.value = "usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -g $new_gid -p $new_crypt_password $old_username";
      this.form.usermod_stdin.value = "";
      this.form.suspend.value = "usermod -L $username";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "usermod -U $username";
      this.form.unsuspend_stdin.value="";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="FreeBSD before 4.10 / 5.3" onClick='
      this.form.useradd.value = "lockf /etc/passwd.lock pw useradd $username -d $dir -m -s $shell -u $uid -c $finger -h 0";
      this.form.useradd_stdin.value = "$_password\n";
      this.form.userdel.value = "lockf /etc/passwd.lock pw userdel $username -r"; this.form.userdel_stdin.value="";
      this.form.usermod.value = "lockf /etc/passwd.lock pw usermod $old_username -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -g $new_gid -c $new_finger -h 0";
      this.form.usermod_stdin.value = "$new__password\n"; this.form.suspend.value = "lockf /etc/passwd.lock pw lock $username";
      this.form.suspend_stdin.value="";
      this.form.unsuspend.value = "lockf /etc/passwd.lock pw unlock $username"; this.form.unsuspend_stdin.value="";
    '>
    Note: On FreeBSD versions before 5.3 and 4.10 (4.10 is after 4.9, not
    4.1!), due to deficient locking in pw(1), you must disable the chpass(1),
    chsh(1), chfn(1), passwd(1), and vipw(1) commands, or replace them with
    wrappers that prepend "lockf /etc/passwd.lock".  Alternatively, apply the
    patch in
    <A HREF="http://www.freebsd.org/cgi/query-pr.cgi?pr=23501">FreeBSD PR#23501</A>
    and use the "FreeBSD 4.10 / 5.3 or later" button below.
  <LI>
    <INPUT TYPE="button" VALUE="FreeBSD 4.10 / 5.3 or later" onClick='
      this.form.useradd.value = "pw useradd $username -d $dir -m -s $shell -u $uid -g $gid -c $finger -h 0";
      this.form.useradd_stdin.value = "$_password\n";
      this.form.userdel.value = "pw userdel $username -r";
      this.form.userdel_stdin.value="";
      this.form.usermod.value = "pw usermod $old_username -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -g $new_gid -c $new_finger -h 0";
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
      this.form.usermod.value = "usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -g $new_gid -p $new_crypt_password $old_username";
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
  <LI><code>$quoted_password</code> - unencrypted password, already quoted for the shell (do not add additional quotes).
  <LI><code>$crypt_password</code> - encrypted password.  When used on the command line (rather than STDIN), it will be quoted for the shell already (do not add additional quotes).
  <LI><code>$ldap_password</code> - Password in LDAP/RFC2307 format (for example, "{PLAIN}himom", "{CRYPT}94pAVyK/4oIBk" or "{MD5}5426824942db4253f87a1009fd5d2d4").  When used on the command line (rather than STDIN), it will be quoted for the shell already (do not add additional quotes).
  <LI><code>$uid</code>
  <LI><code>$gid</code>
  <LI><code>$finger</code> - GECOS.  When used on the command line (rather than STDIN), it will be quoted for the shell already (do not add additional quotes).
  <LI><code>$first</code> - First name of GECOS.  When used on the command line (rather than STDIN), it will be quoted for the shell already (do not add additional quotes).
  <LI><code>$last</code> - Last name of GECOS.  When used on the command line (rather than STDIN), it will be quoted for the shell already (do not add additional quotes).
  <LI><code>$dir</code> - home directory
  <LI><code>$shell</code>
  <LI><code>$quota</code>
  <LI><code>@radius_groups</code>
  <LI><code>$reasonnum (when suspending)</code>
  <LI><code>$reasontext (when suspending)</code>
  <LI><code>$reasontypenum (when suspending)</code>
  <LI><code>$reasontypetext (when suspending)</code>
  <LI><code>$pkgnum</code>
  <LI><code>$custnum</code>
  <LI>All other fields in <a href="../docs/schema.html#svc_acct">svc_acct</a> are also available.
</UL>
END
);

sub _groups_susp_reason_map { shift->_map('groups_susp_reason'); }

sub _map {
  my $self = shift;
  map { reverse(/^\s*(\S+)\s*(.*)\s*$/) } split("\n", $self->option(shift) );
}

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
  $self->_export_command_or_super('suspend', @_);
}

sub _export_unsuspend {
  my($self) = shift;
  $self->_export_command_or_super('unsuspend', @_);
}

sub _export_command_or_super {
  my($self, $action) = (shift, shift);
  if ( $self->option($action) =~ /^\s*$/ ) {
    my $method = "SUPER::_export_$action";
    $self->$method(@_);
  } else {
    $self->_export_command($action, @_);
  }
};

sub _export_command {
  my ( $self, $action, $svc_acct) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;
  my $stdin = $self->option($action."_stdin");

  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;

    # snarfs are unused at this point?
    my $count = 1;
    foreach my $acct_snarf ( $svc_acct->acct_snarf ) {
      ${"snarf_$_$count"} = shell_quote( $acct_snarf->get($_) )
        foreach qw( machine username _password );
      $count++;
    }
  }

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    $email = ( grep { $_ !~ /^(POST|FAX)$/ } $cust_pkg->cust_main->invoicing_list )[0];
  } else {
    $email = '';
  }

  $finger =~ /^(.*)\s+(\S+)$/ or $finger =~ /^((.*))$/;
  ($first, $last ) = ( $1, $2 );
  $domain = $svc_acct->domain;

  $quoted_password = shell_quote $_password;

  $crypt_password = $svc_acct->crypt_password( $self->option('crypt') );
  $ldap_password  = $svc_acct->ldap_password(  $self->option('crypt') );

  @radius_groups = $svc_acct->radius_groups;

  my ($reasonnum, $reasontext, $reasontypenum, $reasontypetext);
  if ( $cust_pkg && $action eq 'suspend' &&
       (my $r = $cust_pkg->last_reason('susp')) )
  {
    $reasonnum = $r->reasonnum;
    $reasontext = $r->reason;
    $reasontypenum = $r->reason_type;
    $reasontypetext = $r->reasontype->type;

    my %reasonmap = $self->_groups_susp_reason_map;
    my $userspec = '';
    $userspec = $reasonmap{$reasonnum}
      if exists($reasonmap{$reasonnum});
    $userspec = $reasonmap{$reasontext}
      if (!$userspec && exists($reasonmap{$reasontext}));

    my $suspend_user;
    if ( $userspec =~ /^\d+$/ ) {
      $suspend_user = qsearchs( 'svc_acct', { 'svcnum' => $userspec } );
    } elsif ( $userspec =~ /^\S+\@\S+$/ ) {
      my ($username,$domain) = split(/\@/, $userspec);
      for my $user (qsearch( 'svc_acct', { 'username' => $username } )){
        $suspend_user = $user if $userspec eq $user->email;
      }
    } elsif ($userspec) {
      $suspend_user = qsearchs( 'svc_acct', { 'username' => $userspec } );
    }

    @radius_groups = $suspend_user->radius_groups
      if $suspend_user;  

  } else {
    $reasonnum = $reasontext = $reasontypenum = $reasontypetext = '';
  }

  my $stdin_string = eval(qq("$stdin"));

  $first = shell_quote $first;
  $last = shell_quote $last;
  $finger = shell_quote $finger;
  $crypt_password = shell_quote $crypt_password;
  $ldap_password  = shell_quote $ldap_password;
  $pkgnum = $cust_pkg ? $cust_pkg->pkgnum : '';
  $custnum = $cust_pkg ? $cust_pkg->custnum : '';

  my $command_string = eval(qq("$command"));
  my @ssh_cmd_args = (
    user          => $self->option('user') || 'root',
    host          => $self->machine,
    command       => $command_string,
    stdin_string  => $stdin_string,
  );

  if($self->option($action . '_no_queue')) {
    # discard return value just like freeside-queued.
    eval { ssh_cmd(@ssh_cmd_args) };
    $error = $@;
    return $error. ' ('. $self->exporttype. ' to '. $self->machine. ')'
      if $error;
  }
  else {
    $self->shellcommands_queue( $svc_acct->svcnum, @ssh_cmd_args );
  }
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
  my $old_cust_pkg = $old->cust_svc->cust_pkg;
  my $new_cust_pkg = $new->cust_svc->cust_pkg;
  $new_finger =~ /^(.*)\s+(\S+)$/ or $new_finger =~ /^((.*))$/;
  ($new_first, $new_last ) = ( $1, $2 );
  $quoted_new__password = shell_quote $new__password; #old, wrong?
  $new_quoted_password = shell_quote $new__password; #new, better?
  $old_domain = $old->domain;
  $new_domain = $new->domain;

  $new_crypt_password = $new->crypt_password( $self->option('crypt') );
  $new_ldap_password  = $new->ldap_password(  $self->option('crypt') );

  @old_radius_groups = $old->radius_groups;
  @new_radius_groups = $new->radius_groups;

  my $error = '';
  if ( $self->option('usermod_pwonly') || $self->option('usermod_nousername') ){
    if ( $old_username ne $new_username ) {
      $error ||= "can't change username";
    }
  }
  if ( $self->option('usermod_pwonly') ) {
    if ( $old_domain ne $new_domain ) {
      $error ||= "can't change domain";
    }
    if ( $old_uid != $new_uid ) {
      $error ||= "can't change uid";
    }
    if ( $old_gid != $new_gid ) {
      $error ||= "can't change gid";
    }
    if ( $old_dir ne $new_dir ) {
      $error ||= "can't change dir";
    }
    #if ( join("\n", sort @old_radius_groups) ne
    #     join("\n", sort @new_radius_groups)    ) {
    #  $error ||= "can't change RADIUS groups";
    #}
  }
  return $error. ' ('. $self->exporttype. ' to '. $self->machine. ')'
    if $error;

  my $stdin_string = eval(qq("$stdin"));

  $new_first = shell_quote $new_first;
  $new_last = shell_quote $new_last;
  $new_finger = shell_quote $new_finger;
  $new_crypt_password = shell_quote $new_crypt_password;
  $new_ldap_password  = shell_quote $new_ldap_password;
  $old_pkgnum = $old_cust_pkg ? $old_cust_pkg->pkgnum : '';
  $old_custnum = $old_cust_pkg ? $old_cust_pkg->custnum : '';
  $new_pkgnum = $new_cust_pkg ? $new_cust_pkg->pkgnum : '';
  $new_custnum = $new_cust_pkg ? $new_cust_pkg->custnum : '';

  my $command_string = eval(qq("$command"));

  my @ssh_cmd_args = (
    user          => $self->option('user') || 'root',
    host          => $self->machine,
    command       => $command_string,
    stdin_string  => $stdin_string,
  );

  if($self->option('usermod_no_queue')) {
    # discard return value just like freeside-queued.
    eval { ssh_cmd(@ssh_cmd_args) };
    $error = $@;
    return $error. ' ('. $self->exporttype. ' to '. $self->machine. ')'
      if $error;
  }
  else {
    $self->shellcommands_queue( $new->svcnum, @ssh_cmd_args );
  }
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

