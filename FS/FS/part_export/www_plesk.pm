package FS::part_export::www_plesk;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'URL'       => { label=>'URL' },
  'login'     => { label=>'Login' },
  'password'  => { label=>'Password' },
  'template'  => { label=>'Domain Template' },
  'web'       => { label=>'Host Website',
                    type=>'checkbox'          },
  'debug'     => { label=>'Enable debugging',
                    type=>'checkbox'          },
;

%info = (
  'svc'    => 'svc_www',
  'desc'   => 'Real-time export to Plesk managed hosting service',
  'options'=> \%options,
  'notes'  => <<'END'
Real-time export to
<a href="http://www.swsoft.com/">Plesk</a> managed server.
Requires installation of
<a href="http://search.cpan.org/dist/Net-Plesk">Net::Plesk</a>
from CPAN and proper <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration:www_plesk.pm">configuration</a>.
END
);

sub rebless { shift; }

# experiment: want the status of these right away (don't want account to
# create or whatever and then get error in the queue from dup username or
# something), so no queueing

sub _export_insert {
  my( $self, $www ) = ( shift, shift );

  eval "use Net::Plesk;";
  return $@ if $@;

  my $plesk = new Net::Plesk (
    'POST'              => $self->option('URL'),
    ':HTTP_AUTH_LOGIN'  => $self->option('login'),
    ':HTTP_AUTH_PASSWD' => $self->option('password'),
  );

  my $gcresp = $plesk->client_get( $www->svc_acct->username );
  return $gcresp->errortext
    unless $gcresp->is_success;

  unless ($gcresp->id) {
    my $cust_main = $www->cust_svc->cust_pkg->cust_main;
    $gcresp = $plesk->client_add( $cust_main->name,
                                  $www->svc_acct->username,
                                  $www->svc_acct->_password,
                                  $cust_main->daytime,
                                  $cust_main->fax,
                                  $cust_main->invoicing_list->[0],
                                  $cust_main->address1 . $cust_main->address2,
                                  $cust_main->city,
                                  $cust_main->state,
                                  $cust_main->zip,
                                  $cust_main->country,
				);
    return $gcresp->errortext
      unless $gcresp->is_success;
  }

  $plesk->client_ippool_add_ip ( $gcresp->id,
                                 $www->domain_record->recdata,
       		                );

  if ($self->option('web')) {
    $self->_plesk_command( 'domain_add', 
                           $www->domain_record->svc_domain->domain,
    			   $gcresp->id,
  			   $www->domain_record->recdata,
                           $self->option('template')?$self->option('template'):'',
                           $www->svc_acct->username,
                           $www->svc_acct->_password,
		         );
  }else{
    $self->_plesk_command( 'domain_add', 
                           $www->domain_record->svc_domain->domain,
    			   $gcresp->id,
  			   $www->domain_record->recdata,
                           $self->option('template')?$self->option('template'):'',
		         );
  }
}

sub _plesk_command {
  my( $self, $method, @args ) = @_;

  eval "use Net::Plesk;";
  return $@ if $@;
  
  local($Net::Plesk::DEBUG) = 1
    if $self->option('debug');

  my $plesk = new Net::Plesk (
    'POST'              => $self->option('URL'),
    ':HTTP_AUTH_LOGIN'  => $self->option('login'),
    ':HTTP_AUTH_PASSWD' => $self->option('password'),
  );

  my $response = $plesk->$method(@args);
  return $response->errortext unless $response->is_success;
  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  return "can't change domain with Plesk"
    if $old->domain_record->svc_domain->domain ne
       $new->domain_record->svc_domain->domain;

  return "can't change client with Plesk"
    if $old->svc_acct->username ne
       $new->svc_acct->username;

  return '';

}

sub _export_delete {
  my( $self, $www ) = ( shift, shift );
  $self->_plesk_command( 'domain_del', $www->domain_record->svc_domain->domain);
}

1;

