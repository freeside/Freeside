package FS::part_export::infostreet;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'createUser', $svc_acct->username, $svc_acct->_password );
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

}

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


