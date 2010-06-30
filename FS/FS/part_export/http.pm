package FS::part_export::http;

use base qw( FS::part_export );
use vars qw( %options %info );
use Tie::IxHash;

tie %options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'url'    => { label   => 'URL', default => 'http://', },
  'insert_data' => {
    label   => 'Insert data',
    type    => 'textarea',
    default => join("\n",
      'DomainName $svc_x->domain',
      'Email ( grep { $_ !~ /^(POST|FAX)$/ } $svc_x->cust_svc->cust_pkg->cust_main->invoicing_list)[0]',
      'test 1',
      'reseller $svc_x->cust_svc->cust_pkg->part_pkg->pkg =~ /reseller/i',
    ),
  },
  'delete_data' => {
    label   => 'Delete data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'replace_data' => {
    label   => 'Replace data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
;

%info = (
  'svc'     => 'svc_domain',
  'desc'    => 'Send an HTTP or HTTPS GET or POST request',
  'options' => \%options,
  'notes'   => <<'END'
Send an HTTP or HTTPS GET or POST to the specified URL.  For HTTPS support,
<a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a>
is required.
END
);

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

  my $cust_main = $svc_x->table eq 'cust_main'
                    ? $svc_x
                    : $svc_x->cust_svc->cust_pkg->cust_main;

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

  my $new_cust_main = $new->table eq 'cust_main'
                        ? $new
                        : $new->cust_svc->cust_pkg->cust_main;

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
  my $queue = new FS::queue { 'job' => "FS::part_export::http::http" };
  $queue->svcnum($svcnum) if $svcnum;
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

1;

