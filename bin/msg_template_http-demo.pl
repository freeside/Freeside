=head1 NAME

FS::msg_template::http example server.

=head1 DESCRIPTION

This is an incredibly crude Mojo web service for demonstrating how to talk 
to the HTTP customer messaging interface in Freeside.

It implements an endpoint for the "password reset" messaging case which 
creates a simple password reset message using some template variables,
and a "send" endpoint that just delivers the message by sendmail. The 
configuration to use this as your password reset handler would be:

prepare_url = 'http://localhost:3000/prepare/password_reset'
send_url =    'http://localhost:3000/send'
No username, no password, no additional content.

=cut

use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Simple qw(sendmail);

post '/prepare/password_reset' => sub {
  my $self = shift;

  my $json_data = $self->req->body;
  #print STDERR $json_data;
  my $input = decode_json($json_data);
  if ( $input->{username} ) {
    my $output = {
      'to'      => $input->{invoicing_email},
      'subject' => "Password reset for $input->{username}",
      'body'    => "
To complete your $input->{company_name} password reset, please go to 
$input->{selfservice_server_base_url}/selfservice.cgi?action=process_forgot_password;session_id=$input->{session_id}

This link will expire in 24 hours.",
    };

    return $self->render( json => $output );

  } else {

    return $self->render( text => 'Username required', status => 500 );

  }
};

post '/send' => sub {
  my $self = shift;

  my $json_data = $self->req->body;
  my $input = decode_json($json_data);
  my $email = Email::Simple->create(
    header => [
      From    => $ENV{USER}.'@localhost',
      To      => $input->{to},
      Subject => $input->{subject},
    ],
    body => $input->{body},
  );
  local $@;
  eval { sendmail($email) };
  if ( $@ ) {
    return $self->render( text => $@->message, status => 500 );
  } else {
    return $self->render( text => '' );
  }
};

app->start;

