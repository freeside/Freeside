package FS::part_export::cyrus;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $self->cyrus_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username, $svc_acct->quota );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change username using Cyrus"
    if $old->username ne $new->username;
  return '';
#  #return '' unless $old->_password ne $new->_password;
#  $self->cyrus_queue( $new->svcnum,
#    'replace', $new->username, $new->_password );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->cyrus_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username );
}

#a good idea to queue anything that could fail or take any time
sub cyrus_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::cyrus::cyrus_$method",
  };
  $queue->insert(
    $self->option('server'),
    $self->option('username'),
    $self->option('password'),
    @_
  );
}

sub cyrus_insert { #subroutine, not method
  my $client = cyrus_connect(shift, shift, shift);
  my( $username, $quota ) = @_;
  my $rc = $client->create("user.$username");
  my $error = $client->error;
  die "creating user.$username: $error" if $error;

  $rc = $client->setacl("user.$username", $username => 'all' );
  $error = $client->error;
  die "setacl user.$username: $error" if $error;

  if ( $quota ) {
    $rc = $client->setquota("user.$username", 'STORAGE' => $quota );
    $error = $client->error;
    die "setquota user.$username: $error" if $error;
  }

}

sub cyrus_delete { #subroutine, not method
  my ( $server, $admin_username, $password_username, $username ) = @_;
  my $client = cyrus_connect($server, $admin_username, $password_username);

  my $rc = $client->setacl("user.$username", $admin_username => 'all' );
  my $error = $client->error;
  die $error if $error;

  $rc = $client->delete("user.$username");
  $error = $client->error;
  die $error if $error;
}

sub cyrus_connect {

  my( $server, $admin_username, $admin_password ) = @_;

  eval "use Cyrus::IMAP::Admin;";

  my $client = Cyrus::IMAP::Admin->new($server);
  $client->authenticate(
    -user      => $admin_username,
    -mechanism => "login",       
    -password  => $admin_password,
  );
  $client;

}

#sub cyrus_replace { #subroutine, not method
#}


