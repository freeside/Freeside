package FS::part_export::communigate_pro;

use strict;
use vars qw(@ISA %info %options $DEBUG);
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
  'accountType'   => { label   => 'Type for newly-created accounts',
                       type    => 'select',
                       options => [qw(MultiMailbox TextMailbox MailDirMailbox)],
                       default => 'MultiMailbox',
                     },
  'externalFlag'  => { label   => 'Create accounts with an external (visible for legacy mailers) INBOX.',
                       type    => 'checkbox',
                     },
  'AccessModes'   => { label   => 'Access modes',
                       default => 'Mail POP IMAP PWD WebMail WebSite',
                     },
  'create_domain' => { label   => 'Domain creation API call',
                       type    => 'select',
                       options => [qw( CreateDomain CreateSharedDomain )],
                     }
;

%info = (
  'svc'     => [qw( svc_acct svc_domain )],
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

sub rebless { shift; }

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->email;
}

sub _export_insert {
  my( $self, $svc_x ) = (shift, shift);

  my @options;

  if ( $svc_x->isa('FS::svc_acct') ) {

    @options = ( $svc_x->svcnum, 'CreateAccount',
      'accountName'    => $self->export_username($svc_x),
      'accountType'    => $self->option('accountType'),
      'AccessModes'    => $self->option('AccessModes'),
      'RealName'       => $svc_x->finger,
      'Password'       => $svc_x->_password,
    );
    push @options, 'MaxAccountSize' => $svc_x->quota if $svc_x->quota;
    push @options, 'externalFlag'   => $self->option('externalFlag')
      if $self->option('externalFlag');

  } elsif ( $svc_x->isa('FS::svc_domain') ) {

    my $create = $self->option('create_domain') || 'CreateDomain';

    @options = ( $svc_x->svcnum, $create, $svc_x->domain,
      #other domain creation options?
    );
    push @options, 'AccountsLimit' => $svc_x->max_accounts
      if $svc_x->max_accounts;

  } else {
    die "guru meditation #14: $svc_x is not FS::svc_acct, or FS::svc_domain";
  }

  $self->communigate_pro_queue( @options );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  if ( $new->isa('FS::svc_acct') ) {

    #XXX they probably need the ability to change some of these
    return "can't (yet) change username with CommuniGate Pro"
      if $old->username ne $new->username;
    return "can't (yet) change domain with CommuniGate Pro"
      if $self->export_username($old) ne $self->export_username($new);
    return "can't (yet) change GECOS with CommuniGate Pro"
      if $old->finger ne $new->finger;
    return "can't (yet) change quota with CommuniGate Pro"
      if $old->quota ne $new->quota;
    return '' unless $old->username ne $new->username
                  || $old->_password ne $new->_password
                  || $old->finger ne $new->finger
                  || $old->quota ne $new->quota;

    return '' if '*SUSPENDED* '. $old->_password eq $new->_password;

    #my $err_or_queue = $self->communigate_pro_queue( $new->svcnum,'RenameAccount',
    #  $old->email, $new->email );
    #return $err_or_queue unless ref($err_or_queue);
    #my $jobnum = $err_or_queue->jobnum;

    $self->communigate_pro_queue( $new->svcnum, 'SetAccountPassword',
                                  $self->export_username($new), $new->_password        )
      if $new->_password ne $old->_password;

  }  elsif ( $new->isa('FS::svc_domain') ) {

    if ( $old->domain ne $new->domain ) {
      $self->communigate_pro_queue( $new->svcnum, 'RenameDomain',
        $old->domain, $new->domain,
      );
    }

    if ( $old->max_accounts ne $new->max_accounts ) {
      $self->communigate_pro_queue( $new->svcnum, 'UpdateDomainSettings',
        $new->domain, 'AccountsLimit' => ($new->max_accounts || 'default'),
      );
    }

    #other kinds of changes?

  } else {
    die "guru meditation #15: $new is not FS::svc_acct, or FS::svc_domain";
  }

}

sub _export_delete {
  my( $self, $svc_x ) = (shift, shift);

  if ( $svc_x->isa('FS::svc_acct') ) {

    $self->communigate_pro_queue( $svc_x->svcnum, 'DeleteAccount',
      $self->export_username($svc_x),
    );

  } elsif ( $svc_x->isa('FS::svc_domain') ) {

    $self->communigate_pro_queue( $svc_x->svcnum, 'DeleteDomain',
      $svc_x->domain,
      #XXX turn on force option for domain deletion?
    );

  } else {
    die "guru meditation #16: $svc_x is not FS::svc_acct, or FS::svc_domain";
  }

}

sub _export_suspend {
  my( $self, $svc_x ) = (shift, shift);

  if ( $svc_x->isa('FS::svc_acct') ) {

     $self->communigate_pro_queue( $svc_x->svcnum, 'UpdateAccountSettings',
      'accountName' => $self->export_username($svc_x),
      'AccessModes' => 'Mail',
    );

  } elsif ( $svc_x->isa('FS::svc_domain') ) {

    #XXX domain operations
  } else {
    die "guru meditation #17: $svc_x is not FS::svc_acct, or FS::svc_domain";
  }

}

sub _export_unsuspend {
  my( $self, $svc_x ) = (shift, shift);

  if ( $svc_x->isa('FS::svc_acct') ) {

    $self->communigate_pro_queue( $svc_x->svcnum, 'UpdateAccountSettings',
      'accountName' => $self->export_username($svc_x),
      'AccessModes' => $self->option('AccessModes'),
    );
  } elsif ( $svc_x->isa('FS::svc_domain') ) {

    #XXX domain operations
  } else {
    die "guru meditation #18: $svc_x is not FS::svc_acct, or FS::svc_domain";
  }

}

sub export_getsettings {
  my($self, $svc_x, $settingsref, $defaultref ) = @_;

  my $settings = eval { $self->communigate_pro_runcommand(
    'GetDomainSettings',
    $svc_x->domain
  ) };
  return $@ if $@;

  my $effective_settings = eval { $self->communigate_pro_runcommand(
    'GetDomainEffectiveSettings',
    $svc_x->domain
  ) };
  return $@ if $@;

  my %defaults = map { $_ => 1 }
                   grep !exists(${$settings}{$_}), keys %$effective_settings;

  foreach my $key ( grep ref($effective_settings->{$_}),
                    keys %$effective_settings )
  {
    my $value = $effective_settings->{$key};
    if ( ref($value) eq 'ARRAY' ) {
      $effective_settings->{$key} = join(', ', @$value);
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
  my %kludge_methods = (
    'CreateAccount'         => 'CreateAccount',
    'UpdateAccountSettings' => 'UpdateAccountSettings',
    'CreateDomain'          => 'cp_Scalar_Hash',
    'CreateSharedDomain'    => 'cp_Scalar_Hash',
    'UpdateDomainSettings'  => 'UpdateDomainSettings',
  );
  my $sub = exists($kludge_methods{$method})
              ? $kludge_methods{$method}
              : 'communigate_pro_command';
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::communigate_pro::$sub",
  };
  $queue->insert(
    $self->machine,
    $self->option('port'),
    $self->option('login'),
    $self->option('password'),
    $method,
    @_,
  );

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

#sub cp_Hash {
#  my( $machine, $port, $login, $password, $method, %hash ) = @_;
#  my @args = ( \%hash );
#  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
#}

sub UpdateDomainSettings {
  my( $machine, $port, $login, $password, $method, $domain, %settings ) = @_;
  my @args = ( 'domain' => $domain, 'settings' => \%settings );
  communigate_pro_command( $machine, $port, $login, $password, $method, @args );
}

sub CreateAccount {
  my( $machine, $port, $login, $password, $method, %args ) = @_;
  my $accountName  = delete $args{'accountName'};
  my $accountType  = delete $args{'accountType'};
  my $externalFlag = delete $args{'externalFlag'};
  $args{'AccessModes'} = [ split(' ', $args{'AccessModes'}) ];
  my @args = ( accountName => $accountName,
               accountType  => $accountType,
               settings     => \%args,
             );
               #externalFlag => $externalFlag,
  push @args, externalFlag => $externalFlag if $externalFlag;

  communigate_pro_command( $machine, $port, $login, $password, $method, @args );

}

sub UpdateAccountSettings {
  my( $machine, $port, $login, $password, $method, %args ) = @_;
  my $accountName  = delete $args{'accountName'};
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
    or die "Communigate Pro error: ". $cli->getErrMessage;

  $cli->Logout; # or die "Can't logout of CGPro: $CGP::ERR_STRING\n";

  $return;

}

1;

