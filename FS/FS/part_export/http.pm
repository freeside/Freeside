package FS::part_export::http;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my $self = shift;
  $self->_export_command('insert', @_);
}

sub _export_delete {
  my $self = shift;
  $self->_export_command('delete', @_);
}

sub _export_command {
  my( $self, $action, $svc_x ) = ( shift, shift, shift );

  return unless $self->option("${action}_data");

  $self->http_queue( $svc_x->svcnum,
    $self->option('method'),
    $self->option('url'),
    map {
      /^\s*(\S+)\s+(.*)$/ or /()()/;
      my( $field, $value_expression ) = ( $1, $2 );
      my $value = eval $value_expression;
      die $@ if $@;
      ( $field, $value );
    } split(/\n/, $self->option("${action}_data") )
  );

}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  return unless $self->option('replace_data');

  $self->http_queue( $svc_x->svcnum,
    $self->option('method'),
    $self->option('url'),
    map {
      /^\s*(\S+)\s+(.*)$/ or /()()/;
      my( $field, $value_expression ) = ( $1, $2 );
      die $@ if $@;
      ( $field, $value );
    } split(/\n/, $self->option('replace_data') )
  );

}

sub http_queue {
  my($self, $svcnum) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::http::http",
  };
  $queue->insert( @_ );
}

sub http {
  my($method, $url, @data) = @_;

  $method = lc($method);

  eval "use LWP::UserAgent;";
  die "using LWP::UserAgent: $@" if $@;
  eval "use HTTP::Request::Common;";
  die "using HTTP::Request::Common: $@" if $@;

  my $ua = LWP::UserAgent->new;

  #my $response = $ua->$method(
  #  $url, \%data,
  #  'Content-Type'=>'application/x-www-form-urlencoded'
  #);
  my $req = HTTP::Request::Common::POST( $url, \@data );
  my $response = $ua->request($req);

  die $response->error_as_HTML if $response->is_error;

}

