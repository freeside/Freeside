package FS::part_export::communigate_pro;

use strict;
use vars qw(@ISA %info %options %quotas $DEBUG);
use Data::Dumper;
use Tie::IxHash;
use FS::part_export;
use FS::queue;

@ISA = qw(FS::part_export);

$DEBUG = 1;

tie %options, 'Tie::IxHash',
  'port'          => { label   =>'Port number', default=>'106', },
  'login'         => { label   =>'The administrator account name.  The name can contain a domain part.', },
  'password'      => { label   =>'The administrator account password.', },
  'accountType'   => { label   => 'Type for newly-created accounts (default when not specified in service)',
                       type    => 'select',
                       options => [qw(MultiMailbox TextMailbox MailDirMailbox AGrade BGrade CGrade)],
                       default => 'MultiMailbox',
                     },
  'externalFlag'  => { label   => 'Create accounts with an external (visible for legacy mailers) INBOX.',
                       type    => 'checkbox',
                     },
  'AccessModes'   => { label   => 'Access modes (default when not specified in service)',
                       default => 'Mail POP IMAP PWD WebMail WebSite',
                     },
  'create_domain' => { label   => 'Domain creation API call',
                       type    => 'select',
                       options => [qw( CreateDomain CreateSharedDomain )],
                     }
;

%info = (
  'svc'     => [qw( svc_acct svc_domain svc_forward )],
  'desc'    => 'Real-time export of accounts and domains to a CommuniGate Pro mail server',
  'options' => \%options,
  'notes'   => <<'END'
Real time export of accounts and domains to a
<a href="http://www.stalker.com/CommuniGatePro/">CommuniGate Pro</a>
mail server.  The
<a href="http://www.stalker.com/CGPerl/">CommuniGate Pro Perl Interface</a>
must be installed as CGP::CLI.
END
);

%quotas = (
  'quota'        => 'MaxAccountSize',
  'file_quota'   => 'MaxWebSize',
  'file_maxnum'  => 'MaxWebFiles',
  'file_maxsize' => 'MaxFileSize',
);

sub rebless { shift; }

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->email;
}

sub _export_insert {
  my( $self, $svc_x ) = (shift, shift);

  my $table = $svc_x->table;
  my $method = "_export_insert_$table";
  $self->$method($svc_x, @_);
}

sub _export_insert_svc_acct {
  my( $self, $svc_acct ) = (shift, shift);

  my %settings = (
    'AccessModes'    => [ split(' ', ( $svc_acct->cgp_accessmodes
                                       || $self->option('AccessModes') )
                               )
                        ],
    'RealName'       => $svc_acct->finger,
    'Password'       => $svc_acct->_password,
    map { $quotas{$_} => $svc_acct->$_() }
        grep $svc_acct->$_(), keys %quotas
  );
  #phase 2: pwdallowed, passwordrecovery, allowed mail rules,
  # RPOP modifications, accepts mail to all, add trailer to sent mail
  #phase 3: archive messages, mailing lists

  my @options = ( 'CreateAccount',
    'accountName'    => $self->export_username($svc_acct),
    'accountType'    => ( $svc_acct->cgp_type
                          || $self->option('accountType') ), 
    'settings'       => \%settings
  );

  push @options, 'externalFlag'   => $self->option('externalFlag')
    if $self->option('externalFlag');

  #let's do the create realtime too, for much the same reasons, and to avoid
  #pain of trying to queue w/dep the prefs & aliases
  eval { $self->communigate_pro_runcommand( @options ) };
  return $@ if $@;

  #preferences
  my %prefs = ();
  $prefs{'DeleteMode'} = $svc_acct->cgp_deletemode if $svc_acct->cgp_deletemode;
  $prefs{'EmptyTrash'} = $svc_acct->cgp_emptytrash if $svc_acct->cgp_emptytrash;
  #phase 2: language, time zone, layout, pronto style, send read receipts
  if ( keys %prefs ) {
    my $pref_err = $self->communigate_pro_queue( $svc_acct->svcnum,
      'UpdateAccountPrefs',
      $self->export_username($svc_acct),
      %prefs,
    );
   warn "WARNING: error queueing UpdateAccountPrefs job: $pref_err"
    if $pref_err;
  }

  #aliases
  if ( $svc_acct->cgp_aliases ) {
    my $alias_err = $self->communigate_pro_queue( $svc_acct->svcnum,
      'SetAccountAliases',
      $self->export_username($svc_acct),
      [ split(/\s*[,\s]\s*/, $svc_acct->cgp_aliases) ],
    );
    warn "WARNING: error queueing SetAccountAliases job: $alias_err"
      if $alias_err;
  }

  '';

}

sub _export_insert_svc_domain {
  my( $self, $svc_domain ) = (shift, shift);

  my $create = $self->option('create_domain') || 'CreateDomain';

  my %settings = (
    'DomainAccessModes'    => [ split(' ', $svc_domain->cgp_accessmodes ) ],
  );
  $settings{'AccountsLimit'} = $svc_domain->max_accounts
    if $svc_domain->max_accounts;

  my @options = ( $create, $svc_domain->domain, \%settings );

  eval { $self->communigate_pro_runcommand( @options ) };
  return $@ if $@;

  #aliases
  if ( $svc_domain->cgp_aliases ) {
    my $alias_err = $self->communigate_pro_queue( $svc_domain->svcnum,
      'SetDomainAliases',
      $svc_domain->domain,
      split(/\s*[,\s]\s*/, $svc_domain->cgp_aliases),
    );
    warn "WARNING: error queueing SetDomainAliases job: $alias_err"
      if $alias_err;
  }

  #account defaults

  #account defaults prefs

  '';

}

sub _export_insert_svc_forward {
  my( $self, $svc_forward ) = (shift, shift);

  my $src = $svc_forward->src || $svc_forward->srcsvc_acct->email;
  my $dst = $svc_forward->dst || $svc_forward->dstsvc_acct->email;

  #real-time here, presuming CGP does some dup detection?
  eval { $self->communigate_pro_runcommand( 'CreateForwarder', $src, $dst); };
  return $@ if $@;

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $table = $new->table;
  my $method = "_export_replace_$table";
  $self->$method($new, $old, @_);
}

sub _export_replace_svc_acct {
  my( $self, $new, $old ) = (shift, shift, shift);

  #let's just do the rename part realtime rather than trying to queue
  #w/dependencies.  we don't want FS winding up out-of-sync with the wrong
  #username and a queued job anyway.  right??
  if ( $self->export_username($old) ne $self->export_username($new) ) {
    eval { $self->communigate_pro_runcommand(
      'RenameAccount',
      $self->export_username($old),
      $self->export_username($new),
    ) };
    return $@ if $@;
  }

  if ( $new->_password ne $old->_password
       && '*SUSPENDED* '.$old->_password ne $new->_password
  ) {
    $self->communigate_pro_queue( $new->svcnum, 'SetAccountPassword',
                                  $self->export_username($new), $new->_password
                                );
  }

  my %settings = ();

  $settings{'RealName'} = $new->finger
    if $old->finger ne $new->finger;
  $settings{$quotas{$_}} = $new->$_()
    foreach grep $old->$_() ne $new->$_(), keys %quotas;
  $settings{'accountType'} = $new->cgp_type
    if $old->cgp_type ne $new->cgp_type;
  $settings{'AccessModes'} = $new->cgp_accessmodes
    if $old->cgp_accessmodes ne $new->cgp_accessmodes
    || $old->cgp_type ne $new->cgp_type;

  #phase 2: pwdallowed, passwordrecovery, allowed mail rules,
  # RPOP modifications, accepts mail to all, add trailer to sent mail
  #phase 3: archive messages, mailing lists

  if ( keys %settings ) {
    my $error = $self->communigate_pro_queue(
      $new->svcnum,
      'UpdateAccountSettings',
      $self->export_username($new),
      %settings,
    );
    return $error if $error;
  }

  #preferences
  my %prefs = ();
  $prefs{'DeleteMode'} = $new->cgp_deletemode
    if $old->cgp_deletemode ne $new->cgp_deletemode;
  $prefs{'EmptyTrash'} = $new->cgp_emptytrash
    if $old->cgp_emptytrash ne $new->cgp_emptytrash;
  #phase 2: language, time zone, layout, pronto style, send read receipts
  if ( keys %prefs ) {
    my $pref_err = $self->communigate_pro_queue( $new->svcnum,
      'UpdateAccountPrefs',
      $self->export_username($new),
      %prefs,
    );
   warn "WARNING: error queueing UpdateAccountPrefs job: $pref_err"
    if $pref_err;
  }

  if ( $old->cgp_aliases ne $new->cgp_aliases ) {
    my $error = $self->communigate_pro_queue(
      $new->svcnum,
      'SetAccountAliases',
      $self->export_username($new),
      [ split(/\s*[,\s]\s*/, $new->cgp_aliases) ],
    );
    return $error if $error;
  }

  '';

}

sub _export_replace_svc_domain {
  my( $self, $new, $old ) = (shift, shift, shift);

  if ( $old->domain ne $new->domain ) {
    my $error = $self->communigate_pro_queue( $new->svcnum, 'RenameDomain',
      $old->domain, $new->domain,
    );
    return $error if $error;
  }
  my %settings = ();
  $settings{'AccountsLimit'} = $new->max_accounts
    if $old->max_accounts ne $new->max_accounts;
  $settings{'DomainAccessModes'} = $new->cgp_accessmodes
    if $old->cgp_accessmodes ne $new->cgp_accessmodes;

  if ( keys %settings ) {
    my $error = $self->communigate_pro_queue( $new->svcnum,
      'UpdateDomainSettings',
      $new->domain,
      %settings,
    );
    return $error if $error;
  }

  if ( $old->cgp_aliases ne $new->cgp_aliases ) {
    my $error = $self->communigate_pro_queue( $new->svcnum,
      'SetDomainAliases',
      $new->domain,
      split(/\s*[,\s]\s*/, $new->cgp_aliases),
    );
    return $error if $error;
  }

  #other kinds of changes?

  '';
}

sub _export_replace_svc_forward {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $osrc = $old->src || $old->srcsvc_acct->email;
  my $nsrc = $new->src || $new->srcsvc_acct->email;
  my $odst = $old->dst || $old->dstsvc_acct->email;
  my $ndst = $new->dst || $new->dstsvc_acct->email;

  if ( $odst ne $ndst ) {

    #no change command, so delete and create (real-time)
    eval { $self->communigate_pro_runcommand('DeleteForwarder', $osrc) };
    return $@ if $@;
    eval { $self->communigate_pro_runcommand('CreateForwarder', $nsrc, $ndst)};
    return $@ if $@;

  } elsif ( $osrc ne $nsrc ) {

    #real-time here, presuming CGP does some dup detection?
    eval { $self->communigate_pro_runcommand( 'RenameForwarder', $osrc, $nsrc)};
    return $@ if $@;

  } else {
    warn "communigate replace called for svc_forward with no changes\n";#confess
  }

  '';
}

sub _export_delete {
  my( $self, $svc_x ) = (shift, shift);

  my $table = $svc_x->table;
  my $method = "_export_delete_$table";
  $self->$method($svc_x, @_);
}

sub _export_delete_svc_acct {
  my( $self, $svc_acct ) = (shift, shift);

  $self->communigate_pro_queue( $svc_acct->svcnum, 'DeleteAccount',
    $self->export_username($svc_acct),
  );
}

sub _export_delete_svc_domain {
  my( $self, $svc_domain ) = (shift, shift);

  $self->communigate_pro_queue( $svc_domain->svcnum, 'DeleteDomain',
    $svc_domain->domain,
    #XXX turn on force option for domain deletion?
  );
}

sub _export_delete_svc_forward {
  my( $self, $svc_forward ) = (shift, shift);

  $self->communigate_pro_queue( $svc_forward->svcnum, 'DeleteForwarder',
    ($svc_forward->src || $svc_forward->srcsvc_acct->email),
  );
}

sub _export_suspend {
  my( $self, $svc_x ) = (shift, shift);

  my $table = $svc_x->table;
  my $method = "_export_suspend_$table";
  $self->$method($svc_x, @_);

}

sub _export_suspend_svc_acct {
  my( $self, $svc_acct ) = (shift, shift);

  #XXX is this the desired suspnsion action?

   $self->communigate_pro_queue(
    $svc_acct->svcnum,
    'UpdateAccountSettings',
    $self->export_username($svc_acct),
    'AccessModes' => 'Mail',
  );

}

sub _export_suspend_svc_domain {
  my( $self, $svc_domain) = (shift, shift);

  #XXX domain operations
  '';

}

sub _export_unsuspend {
  my( $self, $svc_x ) = (shift, shift);

  my $table = $svc_x->table;
  my $method = "_export_unsuspend_$table";
  $self->$method($svc_x, @_);

}

sub _export_unsuspend_svc_acct {
  my( $self, $svc_acct ) = (shift, shift);

  $self->communigate_pro_queue(
    $svc_acct->svcnum,
    'UpdateAccountSettings',
    $self->export_username($svc_acct),
    'AccessModes' => ( $svc_acct->cgp_accessmodes
                         || $self->option('AccessModes') ),
  );

}

sub _export_unsuspend_svc_domain {
  my( $self, $svc_domain) = (shift, shift);

  #XXX domain operations
  '';

}


sub export_getsettings {
  my($self, $svc_x) = (shift, shift);

  my $table = $svc_x->table;
  my $method = "export_getsettings_$table";

  $self->can($method) ? $self->$method($svc_x, @_) : '';

}

sub export_getsettings_svc_domain {
  my($self, $svc_domain, $settingsref, $defaultref ) = @_;

  my $settings = eval { $self->communigate_pro_runcommand(
    'GetDomainSettings',
    $svc_domain->domain
  ) };
  return $@ if $@;

  my $effective_settings = eval { $self->communigate_pro_runcommand(
    'GetDomainEffectiveSettings',
    $svc_domain->domain
  ) };
  return $@ if $@;

  my $acct_defaults = eval { $self->communigate_pro_runcommand(
    'GetAccountDefaults',
    $svc_domain->domain
  ) };
  return $@ if $@;

  #warn Dumper($acct_defaults);

  %$effective_settings = ( %$effective_settings,
                           map { ("Acct. Default $_" => $acct_defaults->{$_}); }
                               keys(%$acct_defaults)
                         );

  #aliases too
  my $aliases = eval { $self->communigate_pro_runcommand(
    'GetDomainAliases',
    $svc_domain->domain
  ) };
  return $@ if $@;

  $effective_settings->{'Aliases'} = join(', ', @$aliases);
  $settings->{'Aliases'}           = join(', ', @$aliases);


  #false laziness w/below
  
  my %defaults = map { $_ => 1 }
                   grep !exists(${$settings}{$_}), keys %$effective_settings;

  foreach my $key ( grep ref($effective_settings->{$_}),
                    keys %$effective_settings )
  {
    my $value = $effective_settings->{$key};
    if ( ref($value) eq 'ARRAY' ) {
      $effective_settings->{$key} = join(' ', @$value);
    } else {
      #XXX
      warn "serializing ". ref($value). " for table display not yet handled";
    }
  }

  %{$settingsref} = %$effective_settings;
  %{$defaultref} = %defaults;

  '';
}

sub export_getsettings_svc_acct {
  my($self, $svc_acct, $settingsref, $defaultref ) = @_;

  my $settings = eval { $self->communigate_pro_runcommand(
    'GetAccountSettings',
    $svc_acct->email
  ) };
  return $@ if $@;

  delete($settings->{'Password'});

  my $effective_settings = eval { $self->communigate_pro_runcommand(
    'GetAccountEffectiveSettings',
    $svc_acct->email
  ) };
  return $@ if $@;

  delete($effective_settings->{'Password'});

  #prefs/effectiveprefs too

  my $prefs = eval { $self->communigate_pro_runcommand(
    'GetAccountPrefs',
    $svc_acct->email
  ) };
  return $@ if $@;

  my $effective_prefs = eval { $self->communigate_pro_runcommand(
    'GetAccountEffectivePrefs',
    $svc_acct->email
  ) };
  return $@ if $@;

  %$effective_settings = ( %$effective_settings,
                           map { ("Pref $_" => $effective_prefs->{$_}); }
                               keys(%$effective_prefs)
                         );
  %$settings = ( %$settings,
                 map { ("Pref $_" => $prefs->{$_}); }
                     keys(%$prefs)
               );

  #aliases too

  my $aliases = eval { $self->communigate_pro_runcommand(
    'GetAccountAliases',
    $svc_acct->email
  ) };
  return $@ if $@;

  $effective_settings->{'Aliases'} = join(', ', @$aliases);
  $settings->{'Aliases'}           = join(', ', @$aliases);

  #false laziness w/above

  my %defaults = map { $_ => 1 }
                   grep !exists(${$settings}{$_}), keys %$effective_settings;

  foreach my $key ( grep ref($effective_settings->{$_}),
                    keys %$effective_settings )
  {
    my $value = $effective_settings->{$key};
    if ( ref($value) eq 'ARRAY' ) {
      $effective_settings->{$key} = join(' ', @$value);
    } else {
      #XXX
      warn "serializing ". ref($value). " for table display not yet handled";
    }
  }

  %{$settingsref} = %$effective_settings;
  %{$defaultref} = %defaults;

  '';

}

sub communigate_pro_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $jobnum = ''; #don't actually care
  $self->communigate_pro_queue_dep( \$jobnum, $svcnum, $method, @_);
}

sub communigate_pro_queue_dep {
  my( $self, $jobnumref, $svcnum, $method ) = splice(@_,0,4);

  my %kludge_methods = (
    #'CreateAccount'         => 'CreateAccount',
    'UpdateAccountSettings' => 'UpdateAccountSettings',
    'UpdateAccountPrefs'    => 'cp_Scalar_Hash',
    #'CreateDomain'          => 'cp_Scalar_Hash',
    #'CreateSharedDomain'    => 'cp_Scalar_Hash',
    'UpdateDomainSettings'  => 'UpdateDomainSettings',
    'SetDomainAliases'      => 'cp_Scalar_Array',
  );
  my $sub = exists($kludge_methods{$method})
              ? $kludge_methods{$method}
              : 'communigate_pro_command';

  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::communigate_pro::$sub",
  };
  my $error = $queue->insert(
    $self->machine,
    $self->option('port'),
    $self->option('login'),
    $self->option('password'),
    $method,
    @_,
  );
  $$jobnumref = $queue->jobnum unless $error;

  return $error;
}

sub communigate_pro_runcommand {
  my( $self, $method ) = (shift, shift);

  communigate_pro_command(
    $self->machine,
    $self->option('port'),
    $self->option('login'),
    $self->option('password'),
    $method,
    @_,
  );

}

#XXX one sub per arg prototype is lame.  more magic?  i suppose queue needs
# to store data strctures properly instead of just an arg list.  right.

sub cp_Scalar_Hash {
  my( $machine, $port, $login, $password, $method, $scalar, %hash ) = @_;
  my @args = ( $scalar, \%hash );
  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
}

sub cp_Scalar_Array {
  my( $machine, $port, $login, $password, $method, $scalar, @array ) = @_;
  my @args = ( $scalar, \@array );
  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
}

#sub cp_Hash {
#  my( $machine, $port, $login, $password, $method, %hash ) = @_;
#  my @args = ( \%hash );
#  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
#}

sub UpdateDomainSettings {
  my( $machine, $port, $login, $password, $method, $domain, %settings ) = @_;
  $settings{'DomainAccessModes'} = [split(' ',$settings{'DomainAccessModes'})];
  my @args = ( 'domain' => $domain, 'settings' => \%settings );
  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
}

#sub CreateAccount {
#  my( $machine, $port, $login, $password, $method, %args ) = @_;
#  my $accountName  = delete $args{'accountName'};
#  my $accountType  = delete $args{'accountType'};
#  my $externalFlag = delete $args{'externalFlag'};
#  $args{'AccessModes'} = [ split(' ', $args{'AccessModes'}) ];
#  my @args = ( accountName  => $accountName,
#               accountType  => $accountType,
#               settings     => \%args,
#             );
#               #externalFlag => $externalFlag,
#  push @args, externalFlag => $externalFlag if $externalFlag;
#
#  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
#
#}

sub UpdateAccountSettings {
  my( $machine, $port, $login, $password, $method, $accountName, %args ) = @_;
  $args{'AccessModes'} = [ split(' ', $args{'AccessModes'}) ];
  my @args = ( $accountName, \%args );
  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
}

sub communigate_pro_command { #subroutine, not method
  my( $machine, $port, $login, $password, $method, @args ) = @_;

  eval "use CGP::CLI";

  my $cli = new CGP::CLI( {
    'PeerAddr' => $machine,
    'PeerPort' => $port,
    'login'    => $login,
    'password' => $password,
  } ) or die "Can't login to CGPro: $CGP::ERR_STRING\n";

  #warn "$method ". Dumper(@args) if $DEBUG;

  my $return = $cli->$method(@args)
    or die "Communigate Pro error: ". $cli->getErrMessage. "\n";

  $cli->Logout; # or die "Can't logout of CGPro: $CGP::ERR_STRING\n";

  $return;

}

1;

