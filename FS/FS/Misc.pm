package FS::Misc;

use strict;
use vars qw ( @ISA @EXPORT_OK );
use Exporter;

@ISA = qw( Exporter );
@EXPORT_OK = qw( send_email );

=head1 NAME

FS::Misc - Miscellaneous subroutines

=head1 SYNOPSIS

  use FS::Misc qw(send_email);

  send_email();

=head1 DESCRIPTION

Miscellaneous subroutines.  This module contains miscellaneous subroutines
called from multiple other modules.  These are not OO or necessarily related,
but are collected here to elimiate code duplication.

=head1 SUBROUTINES

=over 4

=item send_email OPTION => VALUE ...

Options:

I<from> - (required)

I<to> - (required) comma-separated scalar or arrayref of recipients

I<subject> - (required)

I<content-type> - (optional) MIME type

I<body> - (required) arrayref of body text lines

=cut

use vars qw( $conf );
use Date::Format;
use Mail::Header;
use Mail::Internet 1.44;
use FS::UID;

FS::UID->install_callback( sub {
  $conf = new FS::Conf;
} );

sub send_email {
  my(%options) = @_;

  $ENV{MAILADDRESS} = $options{'from'};
  my $to = ref($options{to}) ? join(', ', @{ $options{to} } ) : $options{to};
  my @header = (
    'From: '.     $options{'from'},
    'To: '.       $to,
    'Sender: '.   $options{'from'},
    'Reply-To: '. $options{'from'},
    'Date: '.     time2str("%a, %d %b %Y %X %z", time),
    'Subject: '.  $options{'subject'},
  );
  push @header, 'Content-Type: '. $options{'content-type'}
    if exists($options{'content-type'});
  my $header = new Mail::Header ( \@header );

  my $message = new Mail::Internet (
    'Header' => $header,
    'Body'   => $options{'body'},
  );

  my $smtpmachine = $conf->config('smtpmachine');
  $!=0;

  my $rv = $message->smtpsend( 'Host' => $smtpmachine )
    or $message->smtpsend( Host => $smtpmachine, Debug => 1 );

  if ($rv) { #smtpsend returns a list of addresses, not true/false
    return '';
  } else {
    return "can't send email to $to via server $smtpmachine with SMTP: $!";
  }  

}

=head1 BUGS

This package exists.

=head1 SEE ALSO

L<FS::UID>, L<FS::CGI>, L<FS::Record>, the base documentation.

=cut

1;
