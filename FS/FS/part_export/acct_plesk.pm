package FS::part_export::acct_plesk;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'URL'       => { label=>'URL' },
  'login'     => { label=>'Login' },
  'password'  => { label=>'Password' },
  'debug'     => { label=>'Enable debugging',
                    type=>'checkbox'          },
;

%info = (
  'svc'    => 'svc_acct',
  'desc'   => 'Real-time export to Plesk managed mail service',
  'options'=> \%options,
  'notes'  => <<'END'
Real-time export to
<a href="http://www.swsoft.com/">Plesk</a> managed server.
Requires installation of
<a href="http://search.cpan.org/dist/Net-Plesk">Net::Plesk</a>
from CPAN and proper <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration:acct_plesk.pm">configuration</a>.
END
);

sub rebless { shift; }

# experiment: want the status of these right away (don't want account to
# create or whatever and then get error in the queue from dup username or
# something), so no queueing

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);

  $self->_plesk_command( 'mail_add',
                                    $svc_acct->domain,
                                    $svc_acct->username,
                                    $svc_acct->_password,
                                   ) ||
  $self->_export_unsuspend($svc_acct);
}

sub _plesk_command {
  my( $self, $method, $domain, @args ) = @_;

  eval "use Net::Plesk;";
  return $@ if $@;
  
  local($Net::Plesk::DEBUG) = 1
    if $self->option('debug');

  my $plesk = new Net::Plesk (
    'POST'              => $self->option('URL'),
    ':HTTP_AUTH_LOGIN'  => $self->option('login'),
    ':HTTP_AUTH_PASSWD' => $self->option('password'),
  );

  my $dresponse = $plesk->domain_get( $domain );
  return $dresponse->errortext unless $dresponse->is_success;
  my $domainID = $dresponse->id;

  my $response = $plesk->$method($dresponse->id, @args);
  return $response->errortext unless $response->is_success;
  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  return "can't change domain with Plesk"
    if $old->domain ne $new->domain;
  return "can't change username with Plesk"
    if $old->username ne $new->username;
  return '' unless $old->_password ne $new->_password;

  $self->_plesk_command( 'mail_set',
                       $new->domain,
                       $new->username,
                       $new->_password,
		       $old->cust_svc->cust_pkg->susp ? 0 : 1,
                     );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);

  $self->_plesk_command( 'mail_remove',
                       $svc_acct->domain,
                       $svc_acct->username,
                     );
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);

  $self->_plesk_command( 'mail_set',
                       $svc_acct->domain,
                       $svc_acct->username,
                       $svc_acct->_password,
		       0,
                     );
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);

  $self->_plesk_command( 'mail_set',
                       $svc_acct->domain,
                       $svc_acct->username,
                       $svc_acct->_password,
		       1,
                     );
}

1;

