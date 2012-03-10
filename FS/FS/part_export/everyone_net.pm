package FS::part_export::everyone_net;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'clientID'  => { label=>'clientID' },
  'password'  => { label=>'Password' },
  #'workgroup' => { label=>'Default Workgroup' },
  'debug'     => { label=>'Enable debugging',
                    type=>'checkbox'          },
;

%info = (
  'svc'    => 'svc_acct',
  'desc'   => 'Real-time export to Everyone.net outsourced mail service',
  'options'=> \%options,
  'notes'  => <<'END'
Real-time export to
<a href="http://www.everyone.net/">Everyone.net</a> via the XRC Remote API.
Requires installation of
<a href="http://search.cpan.org/dist/Net-XRC">Net::XRC</a>
from CPAN.
END
);

sub rebless { shift; }

# experiement: want the status of these right away (don't want account to
# create or whatever and then get error in the queue from dup username or
# something), so no queueing

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);

  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  $self->_xrc_command( 'createUser',
                       $svc_acct->domain,
                       [],
                       string($svc_acct->username),
                       string($svc_acct->_password),
                     );
}

sub _xrc_command {
  my( $self, $method, $domain, @args ) = @_;
  
  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  local($Net::XRC::DEBUG) = 1
    if $self->option('debug');

  my $xrc = new Net::XRC (
    'clientID' => $self->option('clientID'),
    'password' => $self->option('password'),
  );

  my $dresponse = $xrc->lookupMXReadyClientIDByEmailDomain( string($domain) );
  return $dresponse->error unless $dresponse->is_success;
  my $clientID = $dresponse->content;
  return "clientID for domain $domain not found"
    if $clientID == -1;

  my $response = $xrc->$method($clientID, @args);
  return $response->error unless $response->is_success;
  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  return "can't change domain with Everyone.net"
    if $old->domain ne $new->domain;
  return "can't change username with Everyone.net"
    if $old->username ne $new->username;
  return '' unless $old->_password ne $new->_password;

  $self->_xrc_command( 'setUserPassword',
                       $new->domain,
                       string($new->username),
                       string($new->_password),
                     );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);

  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  $self->_xrc_command( 'deleteUser',
                       $svc_acct->domain,
                       string($svc_acct->username),
                     );
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);

  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  $self->_xrc_command( 'suspendUser',
                       $svc_acct->domain,
                       string($svc_acct->username),
                     );
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);

  eval "use Net::XRC qw(:types);";
  return $@ if $@;

  $self->_xrc_command( 'unsuspendUser',
                       $svc_acct->domain,
                       string($svc_acct->username),
                     );
}

1;

