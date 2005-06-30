package FS::Misc;

use strict;
use vars qw ( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use Carp;
use Data::Dumper;

@ISA = qw( Exporter );
@EXPORT_OK = qw( send_email send_fax );

$DEBUG = 0;

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

I<content-type> - (optional) MIME type for the body

I<body> - (required unless I<nobody> is true) arrayref of body text lines

I<mimeparts> - (optional, but required if I<nobody> is true) arrayref of MIME::Entity->build PARAMHASH refs or MIME::Entity objects.  These will be passed as arguments to MIME::Entity->attach().

I<nobody> - (optional) when set true, send_email will ignore the I<body> option and simply construct a message with the given I<mimeparts>.  In this case,
I<content-type>, if specified, overrides the default "multipart/mixed" for the outermost MIME container.

I<content-encoding> - (optional) when using nobody, optional top-level MIME
encoding which, if specified, overrides the default "7bit".

I<type> - (optional) type parameter for multipart/related messages

=cut

use vars qw( $conf );
use Date::Format;
use Mail::Header;
use Mail::Internet 1.44;
use MIME::Entity;
use FS::UID;

FS::UID->install_callback( sub {
  $conf = new FS::Conf;
} );

sub send_email {
  my(%options) = @_;
  if ( $DEBUG ) {
    my %doptions = %options;
    $doptions{'body'} = '(full body not shown in debug)';
    warn "FS::Misc::send_email called with options:\n  ". Dumper(\%doptions);
#         join("\n", map { "  $_: ". $options{$_} } keys %options ). "\n"
  }

  $ENV{MAILADDRESS} = $options{'from'};
  my $to = ref($options{to}) ? join(', ', @{ $options{to} } ) : $options{to};

  my @mimeargs = ();
  my @mimeparts = ();
  if ( $options{'nobody'} ) {

    croak "'mimeparts' option required when 'nobody' option given\n"
      unless $options{'mimeparts'};

    @mimeparts = @{$options{'mimeparts'}};

    @mimeargs = (
      'Type'         => ( $options{'content-type'} || 'multipart/mixed' ),
      'Encoding'     => ( $options{'content-encoding'} || '7bit' ),
    );

  } else {

    @mimeparts = @{$options{'mimeparts'}}
      if ref($options{'mimeparts'}) eq 'ARRAY';

    if (scalar(@mimeparts)) {

      @mimeargs = (
        'Type'     => 'multipart/mixed',
        'Encoding' => '7bit',
      );
  
      unshift @mimeparts, { 
        'Type'        => ( $options{'content-type'} || 'text/plain' ),
        'Data'        => $options{'body'},
        'Encoding'    => ( $options{'content-type'} ? '-SUGGEST' : '7bit' ),
        'Disposition' => 'inline',
      };

    } else {
    
      @mimeargs = (
        'Type'     => ( $options{'content-type'} || 'text/plain' ),
        'Data'     => $options{'body'},
        'Encoding' => ( $options{'content-type'} ? '-SUGGEST' : '7bit' ),
      );

    }

  }

  my $domain;
  if ( $options{'from'} =~ /\@([\w\.\-]+)/ ) {
    $domain = $1;
  } else {
    warn 'no domain found in invoice from address '. $options{'from'}.
         '; constructing Message-ID @example.com'; 
    $domain = 'example.com';
  }
  my $message_id = join('.', rand()*(2**32), $$, time). "\@$domain";

  my $message = MIME::Entity->build(
    'From'       => $options{'from'},
    'To'         => $to,
    'Sender'     => $options{'from'},
    'Reply-To'   => $options{'from'},
    'Date'       => time2str("%a, %d %b %Y %X %z", time),
    'Subject'    => $options{'subject'},
    'Message-ID' => "<$message_id>",
    @mimeargs,
  );

  if ( $options{'type'} ) {
    #false laziness w/cust_bill::generate_email
    $message->head->replace('Content-type',
      $message->mime_type.
      '; boundary="'. $message->head->multipart_boundary. '"'.
      '; type='. $options{'type'}
    );
  }

  foreach my $part (@mimeparts) {

    if ( UNIVERSAL::isa($part, 'MIME::Entity') ) {

      warn "attaching MIME part from MIME::Entity object\n"
        if $DEBUG;
      $message->add_part($part);

    } elsif ( ref($part) eq 'HASH' ) {

      warn "attaching MIME part from hashref:\n".
           join("\n", map "  $_: ".$part->{$_}, keys %$part ). "\n"
        if $DEBUG;
      $message->attach(%$part);

    } else {
      croak "mimepart $part isn't a hashref or MIME::Entity object!";
    }

  }

  my $smtpmachine = $conf->config('smtpmachine');
  $!=0;

  $message->mysmtpsend( 'Host'     => $smtpmachine,
                        'MailFrom' => $options{'from'},
                      );

}

=item send_fax OPTION => VALUE ...

Options:

I<dialstring> - (required) 10-digit phone number w/ area code

I<docdata> - (required) Array ref containing PostScript or TIFF Class F document

-or-

I<docfile> - (required) Filename of PostScript TIFF Class F document

...any other options will be passed to L<Fax::Hylafax::Client::sendfax>


=cut

sub send_fax {

  my %options = @_;

  die 'HylaFAX support has not been configured.'
    unless $conf->exists('hylafax');

  eval {
    require Fax::Hylafax::Client;
  };

  if ($@) {
    if ($@ =~ /^Can't locate Fax.*/) {
      die "You must have Fax::Hylafax::Client installed to use invoice faxing."
    } else {
      die $@;
    }
  }

  my %hylafax_opts = map { split /\s+/ } $conf->config('hylafax');

  die 'Called send_fax without a \'dialstring\'.'
    unless exists($options{'dialstring'});

  if (exists($options{'docdata'}) and ref($options{'docdata'}) eq 'ARRAY') {
      my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
      my $fh = new File::Temp(
        TEMPLATE => 'faxdoc.'. $options{'dialstring'} . '.XXXXXXXX',
        DIR      => $dir,
        UNLINK   => 0,
      ) or die "can't open temp file: $!\n";

      $options{docfile} = $fh->filename;

      print $fh @{$options{'docdata'}};
      close $fh;

      delete $options{'docdata'};
  }

  die 'Called send_fax without a \'docfile\' or \'docdata\'.'
    unless exists($options{'docfile'});

  #FIXME: Need to send canonical dialstring to HylaFAX, but this only
  #       works in the US.

  $options{'dialstring'} =~ s/[^\d\+]//g;
  if ($options{'dialstring'} =~ /^\d{10}$/) {
    $options{dialstring} = '+1' . $options{'dialstring'};
  } else {
    return 'Invalid dialstring ' . $options{'dialstring'} . '.';
  }

  my $faxjob = &Fax::Hylafax::Client::sendfax(%options, %hylafax_opts);

  if ($faxjob->success) {
    warn "Successfully queued fax to '$options{dialstring}' with jobid " .
           $faxjob->jobid
      if $DEBUG;
    return '';
  } else {
    return 'Error while sending FAX: ' . $faxjob->trace;
  }

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

    #warn "Headers: \n" . join('',@{$hdr->header});
    #warn "Body: \n" . join('',@{$src->body});

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

=back

=head1 BUGS

This package exists.

=head1 SEE ALSO

L<FS::UID>, L<FS::CGI>, L<FS::Record>, the base documentation.

L<Fax::Hylafax::Client>

=cut

1;
