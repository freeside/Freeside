package FS::part_export::shellcommands;

use vars qw(@ISA %info);
use Tie::IxHash;
use Date::Format;
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

  'pkg_change' => { label=>'Package changed command',
                    default=>'',
                  },

  # run commands on package change for multiple services and roll back the
  #  package change transaciton if one fails?  yuck. no.
  #  if this was really needed, would need to restrict to a single service with
  #  this kind of export configured.
  #'pkg_change_no_queue' => { label=>'Run immediately',
  #                           type =>'checkbox',
  #                         },
  'pkg_change_stdin' => { label=>'Package changed command STDIN',
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
  'fail_on_output' => {
      label => 'Treat any output from the command as an error',
      type  => 'checkbox',
  },
  'ignore_all_errors' => {
      label => 'Ignore all errors from the command',
      type  => 'checkbox',
  },
  'ignored_errors' => { label   => 'Regexes of specific errors to ignore, separated by newlines',
                        type    => 'textarea'
                      },
#  'no_queue' => { label => 'Run command immediately',
#                   type  => 'checkbox',
#                },
;

%info = (
  'svc'         => 'svc_acct',
  'desc'        => 'Real-time export via remote SSH (i.e. useradd, userdel, etc.)',
  'options'     => \%options,
  'nodomain'    => 'Y',
  'svc_machine' => 1,
  'notes'       => <<'END'
Run remote commands via SSH.  Usernames are considered unique (also see
shellcommands_withdomain).  You probably want this if the commands you are
running will not accept a domain as a parameter.  You will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.

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
    <INPUT TYPE="button" VALUE="FreeBSD" onClick='
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
  <LI><code>$locationnum</code>
  <LI><code>$custnum</code>
  <LI>All other fields in <b>svc_acct</b> are also available.
  <LI>The following fields from <b>cust_main</b> are also available (except during replace): company, address1, address2, city, state, zip, county, daytime, night, fax, otaker, agent_custid, locale.  When used on the command line (rather than STDIN), they will be quoted for the shell already (do not add additional quotes).
</UL>
For the package changed command only, the following fields are also available:
<UL>
  <LI>$old_pkgnum and $new_pkgnum
  <LI>$old_pkgpart and $new_pkgpart
  <LI>$old_agent_pkgid and $new_agent_pkgid
  <LI>$old_order_date and $new_order_date
  <LI>$old_start_date and $new_start_date
  <LI>$old_setup and $new_setup
  <LI>$old_bill and $new_bill
  <LI>$old_last_bill and $new_last_bill
  <LI>$old_susp and $new_susp
  <LI>$old_adjourn and $new_adjourn
  <LI>$old_resume and $new_resume
  <LI>$old_cancel and $new_cancel
  <LI>$old_unancel and $new_unancel
  <LI>$old_expire and $new_expire
  <LI>$old_contract_end and $new_contract_end
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
  my $self = shift;
  $self->_export_command('useradd', @_);
}

sub _export_delete {
  my $self = shift;
  $self->_export_command('userdel', @_);
}

sub _export_suspend {
  my $self = shift;
  $self->_export_command_or_super('suspend', @_);
}

sub _export_unsuspend {
  my $self = shift;
  $self->_export_command_or_super('unsuspend', @_);
}

sub export_pkg_change {
  my( $self, $svc_acct, $new_cust_pkg, $old_cust_pkg ) = @_;

  my @fields = qw( pkgnum pkgpart agent_pkgid ); #others?
  my @date_fields = qw( order_date start_date setup bill last_bill susp adjourn
                        resume cancel uncancel expire contract_end );

  no strict 'vars';
  {
    no strict 'refs';
    foreach (@fields) {
      ${"old_$_"} = $old_cust_pkg ? $old_cust_pkg->getfield($_) : '';
      ${"new_$_"} = $new_cust_pkg->getfield($_);
    }
    foreach (@date_fields) {
      ${"old_$_"} = $old_cust_pkg
                      ? time2str('%Y-%m-%d', $old_cust_pkg->getfield($_))
                      : '';
      ${"new_$_"} = time2str('%Y-%m-%d', $new_cust_pkg->getfield($_));
    }
  }

  $self->_export_command('pkg_change', $svc_acct);
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
    # my $count = 1;
    # foreach my $acct_snarf ( $svc_acct->acct_snarf ) {
    #   ${"snarf_$_$count"} = shell_quote( $acct_snarf->get($_) )
    #     foreach qw( machine username _password );
    #   $count++;
    # }
  }

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    no strict 'vars';
    {
      no strict 'refs';
      foreach my $custf (qw( company address1 address2 city state zip country
                             daytime night fax otaker agent_custid locale
                        ))
      {
        ${$custf} = $cust_pkg->cust_main->$custf();
      }
    }
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

  $pkgnum = $cust_pkg ? $cust_pkg->pkgnum : '';
  $locationnum = $cust_pkg ? $cust_pkg->locationnum : '';
  $custnum = $cust_pkg ? $cust_pkg->custnum : '';

  my $stdin_string = eval(qq("$stdin"));
  return "error filling in STDIN: $@" if $@;

  $first = shell_quote $first;
  $last = shell_quote $last;
  $finger = shell_quote $finger;
  $crypt_password = shell_quote $crypt_password;
  $ldap_password  = shell_quote $ldap_password;

  $company = shell_quote $company;
  $address1 = shell_quote $address1;
  $address2 = shell_quote $address2;
  $city = shell_quote $city;
  $state = shell_quote $state;
  $zip = shell_quote $zip;
  $country = shell_quote $country;
  $daytime = shell_quote $daytime;
  $night = shell_quote $night;
  $fax = shell_quote $fax;
  $otaker = shell_quote $otaker; 
  $agent_custid = shell_quote $agent_custid;
  $locale = shell_quote $locale;

  my $command_string = eval(qq("$command"));
  return "error filling in command: $@" if $@;

  my @ssh_cmd_args = (
    user          => $self->option('user') || 'root',
    host          => $self->svc_machine($svc_acct),
    command       => $command_string,
    stdin_string  => $stdin_string,
    ignored_errors    => $self->option('ignored_errors') || '',
    ignore_all_errors => $self->option('ignore_all_errors'),
    fail_on_output    => $self->option('fail_on_output'),
 );

  if ( $self->option($action. '_no_queue') ) {
    # discard return value just like freeside-queued.
    eval { ssh_cmd(@ssh_cmd_args) };
    $error = $@;
    $error = $error->full_message if ref $error; # Exception::Class::Base
    return $error.
             ' ('. $self->exporttype. ' to '. $self->svc_machine($svc_acct). ')'
      if $error;
  } else {
    $self->shellcommands_queue( $svc_acct->svcnum, @ssh_cmd_args );
  }
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  return '' if $command =~ /^\s*$/;
  my $stdin = $self->option('usermod_stdin');
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }
  my $old_cust_pkg = $old->cust_svc->cust_pkg;
  my $new_cust_pkg = $new->cust_svc->cust_pkg;
  my $new_cust_main = $new_cust_pkg ? $new_cust_pkg->cust_main : '';

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
  return $error. ' ('. $self->exporttype. ' to '. $self->svc_machine($new). ')'
    if $error;

  $new_agent_custid = $new_cust_main ? $new_cust_main->agent_custid : '';
  $new_locale = $new_cust_main ? $new_cust_main->locale : '';
  $old_pkgnum = $old_cust_pkg ? $old_cust_pkg->pkgnum : '';
  $old_locationnum = $old_cust_pkg ? $old_cust_pkg->locationnum : '';
  $old_custnum = $old_cust_pkg ? $old_cust_pkg->custnum : '';
  $new_pkgnum = $new_cust_pkg ? $new_cust_pkg->pkgnum : '';
  $new_locationnum = $new_cust_pkg ? $new_cust_pkg->locationnum : '';
  $new_custnum = $new_cust_pkg ? $new_cust_pkg->custnum : '';

  my $stdin_string = eval(qq("$stdin"));

  $new_first = shell_quote $new_first;
  $new_last = shell_quote $new_last;
  $new_finger = shell_quote $new_finger;
  $new_crypt_password = shell_quote $new_crypt_password;
  $new_ldap_password  = shell_quote $new_ldap_password;
  $new_agent_custid = shell_quote $new_agent_custid;
  $new_locale = shell_quote $new_locale;

  my $command_string = eval(qq("$command"));

  my @ssh_cmd_args = (
    user          => $self->option('user') || 'root',
    host          => $self->svc_machine($new),
    command       => $command_string,
    stdin_string  => $stdin_string,
    ignored_errors    => $self->option('ignored_errors') || '',
    ignore_all_errors => $self->option('ignore_all_errors'),
    fail_on_output    => $self->option('fail_on_output'),
  );

  if($self->option('usermod_no_queue')) {
    # discard return value just like freeside-queued.
    eval { ssh_cmd(@ssh_cmd_args) };
    $error = $@;
    $error = $error->full_message if ref $error; # Exception::Class::Base
    return $error. ' ('. $self->exporttype. ' to '. $self->svc_machine($new). ')'
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
  use Net::OpenSSH;
  my $opt = { @_ };
  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null\n";
  my $ssh = Net::OpenSSH->new(
    $opt->{'user'}.'@'.$opt->{'host'},
    'default_stdin_fh' => $def_in
  );
  # ignore_all_errors doesn't override SSH connection/auth errors--
  # probably correct
  die "Couldn't establish SSH connection: ". $ssh->error if $ssh->error;

  my $ssh_opt = {};
  $ssh_opt->{'stdin_data'} = $opt->{'stdin_string'}
    if exists($opt->{'stdin_string'}) and length($opt->{'stdin_string'});

  my ($output, $errput) = $ssh->capture2($ssh_opt, $opt->{'command'});

  return if $opt->{'ignore_all_errors'};
  #die "Error running SSH command: ". $ssh->error if $ssh->error;

  if ( ($output || $errput)
       && $opt->{'ignored_errors'} && length($opt->{'ignored_errors'})
  ) {
    my @ignored_errors = split('\n',$opt->{'ignored_errors'});
    foreach my $ignored_error ( @ignored_errors ) {
        $output =~ s/$ignored_error//g;
        $errput =~ s/$ignored_error//g;
    }
    $output =~ s/[\s\n]//g;
    $errput =~ s/[\s\n]//g;
  }

  die (($errput || $ssh->error). "\n") if $errput || $ssh->error; 
  #die "$errput\n" if $errput;

  die "$output\n" if $output and $opt->{'fail_on_output'};
  '';
}

#sub shellcommands_insert { #subroutine, not method
#}
#sub shellcommands_replace { #subroutine, not method
#}
#sub shellcommands_delete { #subroutine, not method
#}

sub _upgrade_exporttype {
  my $class = shift;
  $class =~ /^FS::part_export::(\w+)$/;
  foreach my $self ( qsearch('part_export', { 'exporttype' => $1 }) ) {
    my %options = $self->options;
    my $changed = 0;
    # 2011-12-13 - 2012-02-16: ignore_all_output option
    if ( $options{'ignore_all_output'} ) {
      # ignoring STDOUT is now the default
      $options{'ignore_all_errors'} = 1;
      delete $options{'ignore_all_output'};
      $changed++;
    }
    my $error = $self->replace(%options) if $changed;
    die $error if $error;
  }
}

1;

