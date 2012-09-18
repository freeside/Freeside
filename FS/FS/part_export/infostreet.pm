package FS::part_export::infostreet;

use vars qw(@ISA %info %infostreet2cust_main $DEBUG);
use Tie::IxHash;
use FS::UID qw(dbh);
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'url'      => { label=>'XML-RPC Access URL', },
  'login'    => { label=>'InfoStreet login', },
  'password' => { label=>'InfoStreet password', },
  'groupID'  => { label=>'InfoStreet groupID', },
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to InfoStreet streetSmartAPI',
  'options'  => \%options,
  'nodomain' => 'Y',
  'no_machine' => 1,
  'notes'    => <<'END'
Real-time export to
<a href="http://www.infostreet.com/">InfoStreet</a> streetSmartAPI.
Requires installation of
<a href="http://search.cpan.org/dist/Frontier-Client">Frontier::Client</a> from CPAN.
END
);

$DEBUG = 0;

%infostreet2cust_main = (
  'firstName'   => 'first',
  'lastName'    => 'last',
  'address1'    => 'address1',
  'address2'    => 'address2',
  'city'        => 'city',
  'state'       => 'state',
  'zipCode'     => 'zip',
  'country'     => 'country',
  'phoneNumber' => 'daytime',
  'faxNumber'   => 'night', #noment-request...
);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  my $cust_main = $svc_acct->cust_svc->cust_pkg->cust_main;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $err_or_queue = $self->infostreet_err_or_queue( $svc_acct->svcnum,
    'createUser', $svc_acct->username, $svc_acct->_password );
  return $err_or_queue unless ref($err_or_queue);
  my $jobnum = $err_or_queue->jobnum;

  my %contact_info = ( map {
    $_ => $cust_main->getfield( $infostreet2cust_main{$_} );
  } keys %infostreet2cust_main );

  my @emails = grep { $_ !~ /^(POST|FAX)$/ } $cust_main->invoicing_list;
  $contact_info{'email'} = $emails[0] if @emails;

  #this one is kinda noment-specific
  $contact_info{'organization'} = $cust_main->agent->agent;

  $err_or_queue = $self->infostreet_queueContact( $svc_acct->svcnum,
    $svc_acct->username, %contact_info );
  return $err_or_queue unless ref($err_or_queue);

  # If a quota has been specified set the quota because it is not the default
  $err_or_queue = $self->infostreet_queueSetQuota( $svc_acct->svcnum, 
    $svc_acct->username, $svc_acct->quota ) if $svc_acct->quota;
  return $err_or_queue unless ref($err_or_queue);

  my $error = $err_or_queue->depend_insert( $jobnum );
  return $error if $error;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change username with InfoStreet"
    if $old->username ne $new->username;

  # If the quota has changed then do the export to setQuota
  my $err_or_queue = $self->infostreet_queueSetQuota( $new->svcnum, $new->username, $new->quota ) 
        if ( $old->quota != $new->quota );  
  return $err_or_queue unless ref($err_or_queue);


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

#ick false laziness
sub infostreet_err_or_queue {
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
  ) or $queue;
}

sub infostreet_queueContact {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::infostreet::infostreet_setContact',
  };
  $queue->insert(
    $self->option('url'),
    $self->option('login'),
    $self->option('password'),
    $self->option('groupID'),
    @_,
  ) or $queue;
}

sub infostreet_setContact {
  my($url, $is_username, $is_password, $groupID, $username, %contact_info) = @_;
  my $accountID = infostreet_command($url, $is_username, $is_password, $groupID,
    'getAccountID', $username);
  foreach my $field ( keys %contact_info ) {
    infostreet_command($url, $is_username, $is_password, $groupID,
      'setContactField', [ 'int'=>$accountID ], $field, $contact_info{$field} );
  }

}

sub infostreet_queueSetQuota {

 my( $self, $svcnum) = (shift, shift);
 my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::infostreet::infostreet_setQuota',
 };

 $queue->insert(
    $self->option('url'),
    $self->option('login'),
    $self->option('password'),
    $self->option('groupID'),
    @_,
 ) or $queue;

}

sub infostreet_setQuota {
  my($url, $is_username, $is_password, $groupID, $username, $quota) = @_;
  infostreet_command($url, $is_username, $is_password, $groupID, 'setQuota', $username, [ 'int'=> $quota ]  );
}


sub infostreet_command { #subroutine, not method
  my($url, $username, $password, $groupID, $method, @args) = @_;

  warn "[FS::part_export::infostreet] $method ".join(' ', @args)."\n" if $DEBUG;

  #quelle hack
  if ( $method =~ /,/ ) {
    foreach my $part ( split(/,\s*/, $method) ) {
      infostreet_command($url, $username, $password, $groupID, $part, @args);
    }
    return;
  }

  eval "use Frontier::Client;";
  die $@ if $@;

  eval 'sub Frontier::RPC2::String::repr {
    my $self = shift;
    my $value = $$self;
    $value =~ s/([&<>\"])/$Frontier::RPC2::char_entities{$1}/ge;
    $value;
  }';
  die $@ if $@;

  my $conn = Frontier::Client->new( url => $url );
  my $key_result = $conn->call( 'authenticate', $username, $password, $groupID);
  my %key_result = _infostreet_parse($key_result);
  die $key_result{error} unless $key_result{success};
  my $key = $key_result{data};

  #my $result = $conn->call($method, $key, @args);
  my $result = $conn->call( $method, $key,
                            map {
                                  if ( ref($_) ) {
                                    my( $type, $value) = @{$_};
                                    $conn->$type($value);
                                  } else {
                                    $conn->string($_);
                                  }
                                } @args );
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

1;

