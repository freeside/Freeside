package FS::ClientAPI_SessionCache;

use strict;
use vars qw($module);
use FS::UID qw(datasrc);
use FS::Conf;

#ask FS::UID to run this stuff for us later
install_callback FS::UID sub { 
  my $conf = new FS::Conf;
  $module = $conf->config('selfservice_server-cache_module')
            || 'Cache::FileCache';
};

=head1 NAME

FS::ClientAPI_SessionCache;

=head1 SYNOPSIS

=head1 DESCRIPTION

Minimal Cache::Cache-alike interface for storing session cache information.
Backends to Cache::SharedMemoryCache, Cache::FileCache, or an internal
implementation which stores information in the clientapi_session and
clientapi_session_field database tables.

=head1 METHODS

=over 4

=item new

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  unless ( $module =~ /^_Database$/ ) {
    eval "use $module;";
    die $@ if $@;
    my $self = $module->new(@_);
    $self->set_cache_root('%%%FREESIDE_CACHE%%%/clientapi_session.'.datasrc)
      if $module =~ /^Cache::FileCache$/;
    $self;
  } else {
    my $self = shift;
    bless ($self, $class);
  }
}

sub get {
  my($self, $session_id) = @_;
  die '_Database self-service session cache not yet implemented';
}

sub set {
  my($self, $session_id, $session, $expiration) = @_;
  die '_Database self-service session cache not yet implemented';
}

sub remove {
  my($self, $session_id) = @_;
  die '_Database self-service session cache not yet implemented';
}

=back

=head1 BUGS

Minimal documentation.

=head1 SEE ALSO

L<Cache::Cache>, L<FS::clientapi_session>, L<FS::clientapi_session_field>

=cut

1;
