package FS::part_event::Action::http;
use base qw( FS::part_event::Action );

use strict;
use vars qw( $me );
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common;
use Cpanel::JSON::XS;
use FS::Misc::DateTime qw( iso8601 );

$me = '[FS::part_event::Action::http]';

#sub description { 'Send an HTTP or HTTPS GET or POST request'; }
sub description { 'Send an HTTP or HTTPS POST request'; }

sub eventtable_hashref {
  { 'cust_bill' => 1,
    'cust_pay'  => 1,
  },
}

sub option_fields {
  (
    'method'        => { label => 'Method',
                         type  => 'select',
                         options => [qw( POST )], #GET )],
                       },
    'url'           => { label => 'URL',
                         type  => 'text',
                         size  => 120,
                       },
    'ssl_no_verify' => { label => 'Skip SSL certificate validation',
                         type  => 'checkbox',
                       },
    'encoding'      => { label => 'Encoding',
                         type  => 'select',
                         options => [qw( JSON )], #XML, Form, etc.
                       },
    'content'       => { label => 'Content', #nneed better inline docs on format
                         type  => 'textarea',
                       },
    #'response_error_param' => 'Response error parameter',
    'debug'         => { label => 'Enable debugging',
                         type  => 'checkbox',
                         value => 1,
                       },
  );
}

sub default_weight { 57; }

our %content_type = (
  'JSON' => 'application/json',
);

sub do_action {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my %content =
    map {
      /^\s*(\S+)\s+(.*)$/ or /()()/;
      my( $field, $value_expression ) = ( $1, $2 );
      my $value = eval $value_expression;
      die $@ if $@;
      ( $field, $value );
    } split(/\n/, $self->option('content') );

  my $content = encode_json( \%content );

  my @lwp_opts = ();
  push @lwp_opts, 'ssl_opts'=>{ 'verify_hostname'=>0 }
    if $self->option('ssl_no_verify');
  my $ua = LWP::UserAgent->new(@lwp_opts);

  my $req = HTTP::Request::Common::POST(
    $self->option('url'),
    Content_Type => $content_type{ $self->option('encoding') },
    Content      => $content,
  );

  if ( $self->option('debug') ) {
    
  }
  my $response = $ua->request($req);

  die $response->status_line if $response->is_error;

  my $response_json = decode_json( $response->content );
  die $response_json->{error} if $response_json->{error}; #XXX response_error_param

}

1;
