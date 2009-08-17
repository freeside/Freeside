package FS::part_export::shellcommands_withdomain;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::shellcommands;

@ISA = qw(FS::part_export::shellcommands);

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 #default=>''
               },
  'useradd_stdin' => { label=>'Insert command STDIN',
                       type =>'textarea',
                       #default=>"$_password\n$_password\n",
                     },
  'useradd_no_queue' => { label => 'Run immediately',
                 type  => 'checkbox',
           },
  'userdel' => { label=>'Delete command',
                 #default=>'',
               },
  'userdel_stdin' => { label=>'Delete command STDIN',
                       type =>'textarea',
                       #default=>'',
                     },
  'userdel_no_queue' => { label => 'Run immediately',
                 type  => 'checkbox',
           },
  'usermod' => { label=>'Modify command',
                 default=>'',
               },
  'usermod_stdin' => { label=>'Modify command STDIN',
                       type =>'textarea',
                       #default=>"$_password\n$_password\n",
                     },
  'usermod_no_queue' => { label => 'Run immediately',
                 type  => 'checkbox',
           },
  'usermod_pwonly' => { label=>'Disallow username, domain, uid, dir and RADIUS group changes',
                        type =>'checkbox',
                      },
  'usermod_nousername' => { label=>'Disallow just username changes',
                            type =>'checkbox',
                          },
  'suspend' => { label=>'Suspension command',
                 default=>'',
               },
  'suspend_stdin' => { label=>'Suspension command STDIN',
                       default=>'',
                     },
  'suspend_no_queue' => { label => 'Run immediately',
                 type  => 'checkbox',
           },
  'unsuspend' => { label=>'Unsuspension command',
                   default=>'',
                 },
  'unsuspend_stdin' => { label=>'Unsuspension command STDIN',
                         default=>'',
                       },
  'unsuspend_no_queue' => { label => 'Run immediately',
                 type  => 'checkbox',
           },
  'crypt' => { label   => 'Default password encryption',
               type=>'select', options=>[qw(crypt md5)],
               default => 'crypt',
             },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Real-time export via remote SSH (vpopmail, ISPMan)',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH.  username@domain (rather than just usernames) are
considered unique (also see shellcommands).  You probably want this if the
commands you are running will accept a domain as a parameter, and will allow
the same username with different domains.  You will need to
<a href="../docs/ssh.html">setup SSH for unattended operation</a>.

<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI><INPUT TYPE="button" VALUE="vpopmail" onClick='
    this.form.useradd.value = "/home/vpopmail/bin/vadduser $username\\\@$domain $quoted_password";
    this.form.useradd_stdin.value = "";
    this.form.userdel.value = "/home/vpopmail/bin/vdeluser $username\\\@$domain";
    this.form.userdel_stdin.value="";
    this.form.usermod.value = "/home/vpopmail/bin/vpasswd $new_username\\\@$new_domain $new_quoted_password";
    this.form.usermod_stdin.value = "";
    this.form.usermod_pwonly.checked = true;
  '>
  <LI><INPUT TYPE="button" VALUE="ISPMan CLI" onClick='
    this.form.useradd.value = "/usr/local/ispman/bin/ispman.addUser -d $domain -f $first -l $last -q $quota -p $quoted_password $username";
    this.form.useradd_stdin.value = "";
    this.form.userdel.value = "/usr/local/ispman/bin/ispman.delUser -d $domain $username";
    this.form.userdel_stdin.value="";
    this.form.usermod.value = "/usr/local/ispman/bin/ispman.passwd.user $new_username\\\@$new_domain $new_quoted_password";
    this.form.usermod_stdin.value = "";
    this.form.usermod_pwonly.checked = true;
  '>
  <LI><INPUT TYPE="button" VALUE="MagicMail" onClick='
    this.form.useradd.value = "/usr/bin/mm_create_email_service -e $svcnum -d $domain -u $username -p $quoted_password -f $first -l $last -m $svcnum -g EMAIL";
    this.form.useradd_stdin.value = "";
    this.form.useradd_no_queue.checked = 1;
    this.form.userdel.value = "/usr/bin/mm_delete_user -e ${username}\\\@${domain}";
    this.form.userdel_stdin.value = "";
    this.form.userdel_no_queue.checked = 1;
    this.form.suspend.value = "/usr/bin/mm_suspend_user -e ${username}\\\@${domain}";
    this.form.suspend_stdin.value = "";
    this.form.unsuspend.value = "/usr/bin/mm_activate_user -e ${username}\\\@${domain}";
    this.form.unsuspend_stdin.value = "";
  '>
</UL>

The following variables are available for interpolation (prefixed with
<code>new_</code> or <code>old_</code> for replace operations):
<UL>
  <LI><code>$username</code>
  <LI><code>$domain</code>
  <LI><code>$_password</code>
  <LI><code>$quoted_password</code> - unencrypted password, already quoted for the shell (do not add additional quotes)
  <LI><code>$crypt_password</code> - encrypted password, already quoted for the shell (do not add additional quotes)
  <LI><code>$uid</code>
  <LI><code>$gid</code>
  <LI><code>$finger</code> - GECOS, already quoted for the shell (do not add additional quotes)
  <LI><code>$first</code> - First name of GECOS, already quoted for the shell (do not add additional quotes)
  <LI><code>$last</code> - Last name of GECOS, already quoted for the shell (do not add additional quotes)
  <LI><code>$dir</code> - home directory
  <LI><code>$shell</code>
  <LI><code>$quota</code>
  <LI><code>@radius_groups</code>
  <LI>All other fields in <a href="../docs/schema.html#svc_acct">svc_acct</a> are also available.
</UL>
END
);

1;

