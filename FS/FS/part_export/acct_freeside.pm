package FS::part_export::acct_freeside;

use vars qw( @ISA %info $DEBUG );
use Data::Dumper;
use Tie::IxHash;
use FS::part_export;
#use FS::Record qw( qsearch qsearchs );
use Frontier::Client;

@ISA = qw(FS::part_export);

$DEBUG = 1;

tie my %options, 'Tie::IxHash',
  'xmlrpc_url'  => { label => 'Full URL to target Freeside xmlrpc.cgi', },
  'ss_username' => { label => 'Self-service username', },
  'ss_domain'   => { label => 'Self-service domain',   },
  'ss_password' => { label => 'Self-service password', },
  'domsvc'      => { label => 'Domain svcnum on target machine', },
  'pkgnum'      => { label => 'Customer package pkgnum on target machine', },
  'svcpart'     => { label => 'Service definition svcpart on target machine', },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Real-time export to another Freeside server',
  'options' => \%options,
  'notes'   => <<END
Real-time export to another Freeside server via self-service.
Requires installation of
<a href="http://search.cpan.org/dist/Frontier-Client">Frontier::Client</a>
from CPAN and setup of an appropriate bulk customer on the other Freeside server.
END
);

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  my $result = $self->_freeside_command('provision_acct',
    'pkgnum'     => $self->option('pkgnum'),
    'svcpart'    => $self->option('svcpart'),
    'username'   => $svc_acct->username,
    '_password'  => $svc_acct->_password,
    '_password2' => $svc_acct->_password,
    'domsvc'     => $self->option('domsvc'),
  );

  $result->{error} || '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $svcnum = $self->_freeside_find_svc( $old );
  return $svcnum unless $svcnum =~ /^(\d+)$/;

  #only pw change supported for now...
  my $result = $self->_freeside_command( 'myaccount_passwd',
                                             'svcnum'        => $svcnum,
                                             'new_password'  => $new->_password,
                                             'new_password2' => $new->_password,
                                       );

  $result->{error} || '';
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);

  my $svcnum = $self->_freeside_find_svc( $svc_acct );
  return $svcnum unless $svcnum =~ /^(\d+)$/;

  my $result = $self->_freeside_command( 'unprovision_svc', 'svcnum'=>$svcnum );

  $result->{'error'} || '';

}

sub _freeside_find_svc {
  my( $self, $svc_acct ) = ( shift, shift );

  my $list_svcs = $self->_freeside_command( 'list_svcs', 'svcdb'=>'svc_acct' );
  my @svc = grep {    $svc_acct->username eq $_->{username}
                   #&& compare domains
                 } @{ $list_svcs->{svcs} };

  return 'multiple services found on target FS' if scalar(@svc) > 1;
  return 'no service found on target FS' if scalar(@svc) == 0; #shouldn't be fatal?

  $svc[0]->{'svcnum'};

}

sub _freeside_command {
  my( $self, $method, @args ) = @_;

  my %login = (
    'username' => $self->option('ss_username'),
    'domain'   => $self->option('ss_domain'),
    'password' => $self->option('ss_password'),
  );
  my $login_result = $self->_do_freeside_command( 'login', %login );
  return $login_result if $login_result->{error};
  my $session_id = $login_result->{session_id};

  #could reuse $session id for replace & delete where we have to find then delete..

  my %command = (
    session_id => $session_id,
    @args
  );
  my $result = $self->_do_freeside_command( $method, %command );

  $result;

}

sub _do_freeside_command {
  my( $self, $method, %args ) = @_;

  # a questionable choice...  but it'll do for now.
  eval "use Frontier::Client;";
  die $@ if $@;

  #reuse?
  my $conn = Frontier::Client->new( url => $self->option('xmlrpc_url') );

  warn "sending FS selfservice $method: ". Dumper(\%args)
    if $DEBUG;
  my $result = $conn->call("FS.SelfService.XMLRPC.$method", \%args);
  warn "FS selfservice $method response: ". Dumper($result)
    if $DEBUG;

  $result;

}

1;
