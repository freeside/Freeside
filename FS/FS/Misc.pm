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

  $message->mysmtpsend( 'Host'     => $smtpmachine,
                        'MailFrom' => $options{'from'},
                      );

}

package Mail::Internet;

use Mail::Address;
use Net::SMTP;

sub Mail::Internet::mysmtpsend {
    my $src  = shift;
    my %opt = @_;
    my $host = $opt{Host};
    my $envelope = $opt{MailFrom};
    my $noquit = 0;
    my $smtp;
    my @hello = defined $opt{Hello} ? (Hello => $opt{Hello}) : ();

    push(@hello, 'Port', $opt{'Port'})
	if exists $opt{'Port'};

    push(@hello, 'Debug', $opt{'Debug'})
	if exists $opt{'Debug'};

    if(ref($host) && UNIVERSAL::isa($host,'Net::SMTP')) {
	$smtp = $host;
	$noquit = 1;
    }
    else {
	#local $SIG{__DIE__};
	#$smtp = eval { Net::SMTP->new($host, @hello) };
	$smtp = new Net::SMTP $host, @hello;
    }

    unless ( defined($smtp) ) {
      my $err = $!;
      $err =~ s/Invalid argument/Unknown host/;
      return "can't connect to $host: $err"
    }

    my $hdr = $src->head->dup;

    _prephdr($hdr);

    # Who is it to

    my @rcpt = map { ref($_) ? @$_ : $_ } grep { defined } @opt{'To','Cc','Bcc'};
    @rcpt = map { $hdr->get($_) } qw(To Cc Bcc)
	unless @rcpt;
    my @addr = map($_->address, Mail::Address->parse(@rcpt));

    return 'No valid destination addresses found!'
	unless(@addr);

    $hdr->delete('Bcc'); # Remove blind Cc's

    # Send it

    my $ok = $smtp->mail( $envelope ) &&
		$smtp->to(@addr) &&
		$smtp->data(join("", @{$hdr->header},"\n",@{$src->body}));

    if ( $ok ) {
      $smtp->quit
          unless $noquit;
      return '';
    } else {
      return $smtp->code. ' '. $smtp->message;
    }

}
package FS::Misc;

=head1 BUGS

This package exists.

=head1 SEE ALSO

L<FS::UID>, L<FS::CGI>, L<FS::Record>, the base documentation.

=cut

1;
