package FS::msg_template::http;
use base qw( FS::msg_template );

use strict;
use vars qw( $DEBUG $conf );

# needed to talk to the external service
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;

# needed to manage prepared messages
use FS::cust_msg;

our $DEBUG = 1;
our $me = '[FS::msg_template::http]';

sub extension_table { 'msg_template_http' }

=head1 NAME

FS::msg_template::http - Send messages via a web service.

=head1 DESCRIPTION

FS::msg_template::http is a message processor in which the message is exported
to a web service, at both the prepare and send stages.

=head1 METHODS

=cut

sub check {
  my $self = shift;
  return 
       $self->ut_textn('prepare_url')
    || $self->ut_textn('send_url')
    || $self->ut_textn('username')
    || $self->ut_textn('password')
    || $self->ut_anything('content')
    || $self->SUPER::check;
}

sub prepare {

  my( $self, %opt ) = @_;

  my $json = JSON->new->canonical(1);

  my $cust_main = $opt{'cust_main'}; # or die 'cust_main required';
  my $object = $opt{'object'} or die 'object required';

  my $hashref = $self->prepare_substitutions(%opt);

  my $document = $json->decode( $self->content || '{}' );
  $document = {
    'msgname' => $self->msgname,
    'msgtype' => $opt{'msgtype'},
    %$document,
    %$hashref
  };

  my $request_content = $json->encode($document);
  warn "$me ".$self->prepare_url."\n" if $DEBUG;
  warn "$request_content\n\n" if $DEBUG > 1;
  my $ua = LWP::UserAgent->new;
  my $request = POST(
    $self->prepare_url,
    'Content-Type' => 'application/json',
    'Content' => $request_content,
  );
  if ( $self->username ) {
    $request->authorization_basic( $self->username, $self->password );
  }
  my $response = $ua->request($request);
  warn "$me received:\n" . $response->as_string . "\n\n" if $DEBUG;

  my $cust_msg = FS::cust_msg->new({
      'custnum'   => $cust_main->custnum,
      'msgnum'    => $self->msgnum,
      '_date'     => time,
      'msgtype'   => ($opt{'msgtype'} || ''),
  });

  if ( $response->is_success ) {
    $cust_msg->set(body => $response->decoded_content);
    $cust_msg->set(status => 'prepared');
  } else {
    $cust_msg->set(status => 'failed');
    $cust_msg->set(error => $response->decoded_content);
  }

  $cust_msg;
}

=item send_prepared CUST_MSG

Takes the CUST_MSG object and sends it to its recipient.

=cut

sub send_prepared {
  my $self = shift;
  my $cust_msg = shift or die "cust_msg required";
  # don't just fail if called as a class method
  if (!ref $self) {
    $self = $cust_msg->msg_template;
  }

  # use cust_msg->header for anything? we _could_...
  my $request_content = $cust_msg->body;

  warn "$me ".$self->send_url."\n" if $DEBUG;
  warn "$request_content\n\n" if $DEBUG > 1;
  my $ua = LWP::UserAgent->new;
  my $request = POST(
    $self->send_url,
    'Content-Type' => 'application/json',
    'Content' => $request_content,
  );
  if ( $self->username ) {
    $request->authorization_basic( $self->username, $self->password );
  }
  my $response = $ua->request($request);
  warn "$me received:\n" . $response->as_string . "\n\n" if $DEBUG;

  my $error;
  if ( $response->is_success ) {
    $cust_msg->set(status => 'sent');
  } else {
    $error = $response->decoded_content;
    $cust_msg->set(error => $error);
    $cust_msg->set(status => 'failed');
  }

  if ( $cust_msg->custmsgnum ) {
    $cust_msg->replace;
  } else {
    $cust_msg->insert;
  }

  $error;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;
