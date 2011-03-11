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
  my $google = $self->google_handle;
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

  my $cache_id = $self->exportnum . '_token';
  $google->{'token'} = $CACHE->get($cache_id);
  if ( !$google->{'token'} ) {
    eval { 
      $google->authenticate(
        'username'  => $self->option('username'),
        'password'  => $self->option('password'),
      ) 
    };
    if ( $@ ) {
      # XXX CAPTCHA
      $google->{'error'} = $@->{'error'};
      $CACHE->remove($cache_id);
      return $google;
    }
    $CACHE->set($cache_id, $google->{'token'}, '1 hour');
  }
  return $google;
}

1;
