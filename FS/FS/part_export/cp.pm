package FS::part_export::cp;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  $self->cp_queue( $svc_acct->svcnum, 'create_mailbox',
    Mailbox   => $svc_acct->username,
    Password  => $svc_acct->_password,
    Workgroup => $self->option('workgroup'),
    Domain    => $svc_acct->domain,
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change domain with Critical Path"
    if $old->domain ne $new->domain;
  return '' unless $old->username  ne $new->username
                || $old->_password ne $new->_password;
  $self->cp_queue( $new->svcnum, 'replace', $new->domain,
    $old->username, $new->username, $old->_password, $new->_password );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->cp_queue( $svc_acct->svcnum, 'delete_mailbox',
    Mailbox   => $svc_acct->username,
    Domain    => $svc_acct->domain,
  );
}

sub cp_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::cp::cp_command',
  };
  $queue->insert(
    $self->machine,
    $self->option('port'),
    $self->option('username'),
    $self->option('password'),
    $self->option('domain'),
    $method,
    @_,
  );
}

sub cp_command { #subroutine, not method
  my($host, $port, $username, $password, $login_domain, $method, @args) = @_;

  #quelle hack
  if ( $method eq 'replace' ) {
  
    my( $domain, $old_username, $new_username, $old_password, $new_password)
      = @args;

    if ( $old_username ne $new_username ) {
      cp_command($host, $port, $username, $password, 'rename_mailbox',
        Domain        => $domain,
        Old_Mailbox   => $old_username,
        New_Mailbox   => $new_username,
      );
    }

    my $other = 'F';
    if ( $new_password =~ /^\*SUSPENDED\* (.*)$/ ) {
      $new_password = $1;
      $other = 'T';
    }
    cp_command($host, $port, $username, $password, 'set_mailbox_status',
      Domain       => $domain,
      Mailbox      => $new_username,
      Other        => $other,
      Other_Bounce => $other,
    );

    if ( $old_password ne $new_password ) {
      cp_command($host, $port, $username, $password, 'change_mailbox',
        Domain    => $domain,
        Mailbox   => $new_username,
        Password  => $new_password,
      );
    }

    return;
  }
  #eof quelle hack

  eval "use Net::APP;";

  my $app = new Net::APP (
    "$host:$port",
    User     => $username,
    Password => $password,
    Domain   => $login_domain,
    Timeout  => 60,
    #Debug    => 1,
  ) or die "$@\n";

  $app->$method( @args );

  die $app->message."\n" unless $app->ok;

}

