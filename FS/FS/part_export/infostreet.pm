package FS::part_export::infostreet;

use vars qw(@ISA %infostreet2cust_main);
use FS::part_export;

@ISA = qw(FS::part_export);

%infostreet2cust_main = (
  'firstName'   => 'first',
  'lastName'    => 'last',
  'address1'    => 'address1',
  'address2'    => 'address2',
  'city'        => 'city',
  'state'       => 'state',
  'zipCode'     => 'zip',
  'country'     => 'country',
  'phoneNumber' => 'dayphone',
);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  my $cust_main = $svc_acct->cust_svc->cust_pkg->cust_main;
  my $accountID = $self->infostreet_queue( $svc_acct->svcnum,
    'createUser', $svc_acct->username, $svc_acct->_password );
  foreach my $infostreet_field ( keys %infostreet2cust_main ) {
    my $error = $self->infostreet_queue( $svc_acct->svcnum,
      'setContactField', $accountID, $infostreet_field,
        $cust_main->getfield( $infostreet2cust_main{$infostreet_field} ) );
    return $error if $error;
  }

  $self->infostreet_queue( $svc_acct->svcnum,
    'setContactField', $accountID, 'email', $cust_main->invoicing_list )
  #this one is kinda noment-specific
  || $self->infostreet_queue( $svc_acct->svcnum,
         'setContactField', $accountID, 'title', $cust_main->agent->agent );

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change username with InfoStreet"
    if $old->username ne $new->username;
  return '' unless $old->_password ne $new->_password;
  $self->infostreet_queue( $new->svcnum,
    'passwd', $new->username, $new->_password );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'purgeAccount,releaseUsername', $svc_acct->username );
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'setStatus', $svc_acct->username, 'DISABLED' );
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'setStatus', $svc_acct->username, 'ACTIVE' );
}

sub infostreet_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::infostreet::infostreet_command',
  };
  $queue->insert(
    $self->option('url'),
    $self->option('login'),
    $self->option('password'),
    $self->option('groupID'),
    $method,
    @_,
  );
}

sub infostreet_command { #subroutine, not method
  my($url, $username, $password, $groupID, $method, @args) = @_;

  #quelle hack
  if ( $method =~ /,/ ) {
    foreach my $part ( split(/,\s*/, $method) ) {
      infostreet_command($url, $username, $password, $groupID, $part, @args);
    }
    return;
  }

  eval "use Frontier::Client;";

  my $conn = Frontier::Client->new( url => $url );
  my $key_result = $conn->call( 'authenticate', $username, $password, $groupID);
  my %key_result = _infostreet_parse($key_result);
  die $key_result{error} unless $key_result{success};
  my $key = $key_result{data};

  #my $result = $conn->call($method, $key, @args);
  my $result = $conn->call($method, $key, map { $conn->string($_) } @args);
  my %result = _infostreet_parse($result);
  die $result{error} unless $result{success};

  $result->{data};

}

#sub infostreet_command_byid { #subroutine, not method;
#  my($url, $username, $password, $groupID, $method, @args ) = @_;
#
#  infostreet_command
#
#}

sub _infostreet_parse { #subroutine, not method
  my $arg = shift;
  map {
    my $value = $arg->{$_};
    #warn ref($value);
    $value = $value->value()
      if ref($value) && $value->isa('Frontier::RPC2::DataType');
    $_=>$value;
  } keys %$arg;
}


