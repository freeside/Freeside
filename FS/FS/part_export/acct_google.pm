package FS::part_export::acct_google;

use strict;
use vars qw(%info %SIG $CACHE);
use Tie::IxHash;
use base 'FS::part_export';

tie my %options, 'Tie::IxHash',
  'domain'    => { label => 'Domain name' },
  'username'  => { label => 'Admin username' },
  'password'  => { label => 'Admin password' },
;
# To handle multiple domains, use separate instances of 
# the export.  We assume that they all have different 
# admin logins.

%info = (
  'svc'       => 'svc_acct',
  'desc'      => 'Google hosted mail',
  'options'   => \%options,
  'nodomain'  => 'Y',
  'notes'    => <<'END'
Export accounts to the Google Provisioning API.  Requires 
REST::Google::Apps::Provisioning from CPAN.
END
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->finger =~ /^(.*)\s+(\S+)$/;
  my ($first, $last) = ($1, $2);
  $self->google_request('createUser',
    'username'      => $svc_acct->username,
    'password'      => $svc_acct->_password,
    'givenName'     => $first,
    'familyName'    => $last,
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  # We have to do this in two steps, so do the renameUser last so that 
  # if it fails partway through the username is still coherent.
  if ( $new->_password ne $old->_password
    or $new->finger    ne $old->finger ) {
    $new->finger =~ /^(.*)\s+(\S+)$/;
    my ($first, $last) = ($1, $2);
    my $error = $self->google_request('updateUser',
      'username'    => $old->username,
      'password'    => $new->_password,
      'givenName'   => $first,
      'familyName'  => $last,
    );
    return $error if $error;
  }
  if ( $new->username ne $old->username ) {
    my $error = $self->google_request('renameUser',
      'username'  => $old->username,
      'newname'   => $new->username
    );
    return $error if $error;
  }
  return;
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->google_request('deleteUser',
    'username'  => $svc_acct->username
  );
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);
  $self->google_request('updateUser',
    'username'  => $svc_acct->username,
    'suspended' => 'true',
  );
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);
  $self->google_request('updateUser',
    'username'  => $svc_acct->username,
    'suspended' => 'false',
  );
}

sub captcha_url {
  my $self = shift;
  my $google = $self->google_handle;
  if (exists ($google->{'captcha_url'}) ) {
    return 'http://www.google.com/accounts/'.$google->{'captcha_url'};
  }
  else {
    return '';
  }
}

sub captcha_auth {
  my $self = shift;
  my $response = shift;
  my $google = $self->google_handle('captcha_response' => $response);
  return (defined($google->{'token'}));
}

my %google_error = (
  1000 => 'unknown error',
  1001 => 'server busy',
  1100 => 'username belongs to a recently deleted account',
  1101 => 'user suspended',
  1200 => 'domain user limit exceeded',
  1201 => 'domain alias limit exceeded',
  1202 => 'domain suspended',
  1203 => 'feature not available on this domain',
  1300 => 'username in use',
  1301 => 'user not found',
  1302 => 'reserved username',
  1400 => 'illegal character in first name',
  1401 => 'illegal character in last name',
  1402 => 'invalid password',
  1403 => 'illegal character in username',
  # should be everything we need
);

# Runs the request and returns nothing if it succeeds, or an 
# error message.

sub google_request {
  my ($self, $method, %opt) = @_;
  my $google = $self->google_handle(
    'captcha_response' => delete $opt{'captcha_response'}
  );
  return $google->{'error'} if $google->{'error'};

  # Throw away the result from this; we don't use it yet.
  eval { $google->$method(%opt) };
  if ( $@ ) {
    return $google_error{ $@->{'error'}->{'errorCode'} } || $@->{'error'};
  }
  return;
}

# Returns a REST::Google::Apps::Provisioning object which is hooked 
# to die {error => stuff} on API errors.  The cached auth token 
# will be used if possible.  If not, try to authenticate.  On 
# authentication error, the R:G:A:P object will still be returned 
# but with $google->{'error'} set to the error message.

sub google_handle {
  my $self = shift;
  my $class = 'REST::Google::Apps::Provisioning';
  my %opt = @_;
  eval "use $class";

  die "failed to load $class\n" if $@;
  $CACHE ||= new Cache::FileCache( {
      'namespace'   => __PACKAGE__,
      'cache_root'  => "$FS::UID::cache_dir/cache.$FS::UID::datasrc",
  } );
  my $google = $class->new( 'domain'  => $self->option('domain') );

  # REST::Google::Apps::Provisioning lacks error reporting.  We deal 
  # with that by hooking HTTP::Response to throw a useful fatal error 
  # on failure.
  $google->{'lwp'}->add_handler( 'response_done' =>
    sub {
      my $response = shift;
      return if $response->is_success;

      my $error = '';
      if ( $response->content =~ /^</ ) {
        #presume xml
        $error = $google->{'xml'}->parse_string($response->content);
      }
      elsif ( $response->content =~ /=/ ) {
        $error = +{ map { if ( /^(\w+)=(.*)$/ ) { lc($1) => $2 } }
          split("\n", $response->content)
        };
      }
      else { # have something to say if there is no response...
        $error = {'error' => $response->status_line};
      }
      die $error;
    }
  );

  my $cache_token = $self->exportnum . '_token';
  my $cache_captcha = $self->exportnum . '_captcha_token';
  $google->{'token'} = $CACHE->get($cache_token);
  if ( !$google->{'token'} ) {
    my %login = (
      'username' => $self->option('username'),
      'password' => $self->option('password'),
    );
    if ( $opt{'captcha_response'} ) {
      $login{'logincaptcha'} = $opt{'captcha_response'};
      $login{'logintoken'} = $CACHE->get($cache_captcha);
    }
    eval { $google->captcha_auth(%login); };
    if ( $@ ) {
      $google->{'error'} = $@->{'error'};
      $google->{'captcha_url'} = $@->{'captchaurl'};
      $CACHE->set($cache_captcha, $@->{'captchatoken'}, '1 minute');
      return $google;
    }
    $CACHE->remove($cache_captcha);
    $CACHE->set($cache_token, $google->{'token'}, '1 hour');
  }
  return $google;
}

# REST::Google::Apps::Provisioning also lacks a way to do this
sub REST::Google::Apps::Provisioning::captcha_auth {
  my $self = shift;

  return( 1 ) if $self->{'token'};

  my ( $arg );
  %{$arg} = @_;

  map { $arg->{lc($_)} = $arg->{$_} } keys %{$arg};

  foreach my $param ( qw/ username password / ) {
    $arg->{$param} || croak( "Missing required '$param' argument" );
  }

  my @postargs = (
    'accountType' => 'HOSTED',
    'service'     => 'apps',
    'Email'       => $arg->{'username'} . '@' . $self->{'domain'},
    'Passwd'      => $arg->{'password'},
  );
  if ( $arg->{'logincaptcha'} ) {
    push @postargs, 
      'logintoken'  => $arg->{'logintoken'},
      'logincaptcha'=> $arg->{'logincaptcha'}
      ;
  }
  my $response = $self->{'lwp'}->post(
    'https://www.google.com/accounts/ClientLogin',
    \@postargs
  );

  $response->is_success() || return( 0 );

  foreach ( split( /\n/, $response->content() ) ) {
    $self->{'token'} = $1 if /^Auth=(.+)$/;
    last if $self->{'token'};
  }

  return( 1 ) if $self->{'token'} || return( 0 );
}

1;
