package FS::msg_template::email;
use base qw( FS::msg_template );

use strict;
use vars qw( $DEBUG $conf );

# stuff needed for template generation
use Date::Format qw( time2str );
use File::Temp;
use IPC::Run qw(run);
use Text::Template;

use HTML::Entities qw( decode_entities encode_entities ) ;
use HTML::FormatText;
use HTML::TreeBuilder;
use Encode;

# needed to send email
use FS::Misc qw( generate_email );
use FS::Conf;
use Email::Sender::Simple qw( sendmail );

use FS::Record qw( qsearch qsearchs );

# needed to manage template_content objects
use FS::template_content;
use FS::UID qw( dbh );

# needed to manage prepared messages
use FS::cust_msg;

FS::UID->install_callback( sub { $conf = new FS::Conf; } );

our $DEBUG = 0;
our $me = '[FS::msg_template::email]';

=head1 NAME

FS::msg_template::email - Construct email notices with Text::Template.

=head1 DESCRIPTION

FS::msg_template::email is a message processor in which the template contains 
L<Text::Template> strings for the message subject line and body, and the 
message is delivered by email.

Currently the C<from_addr> and C<bcc_addr> fields used by this processor are
in the main msg_template table.

=head1 METHODS

=over 4

=item insert [ CONTENT ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

A default (no locale) L<FS::template_content> object will be created.  CONTENT 
is an optional hash containing 'subject' and 'body' for this object.

=cut

sub insert {
  my $self = shift;
  my %content = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( !$error ) {
    $content{'msgnum'} = $self->msgnum;
    $content{'subject'} ||= '';
    $content{'body'} ||= '';
    my $template_content = new FS::template_content (\%content);
    $error = $template_content->insert;
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit if $oldAutoCommit;
  return;
}

=item replace [ OLD_RECORD ] [ CONTENT ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

CONTENT is an optional hash containing 'subject', 'body', and 'locale'.  If 
supplied, an L<FS::template_content> object will be created (or modified, if 
one already exists for this locale).

=cut

sub replace {
  my $self = shift;
  my $old = ( ref($_[0]) and $_[0]->isa('FS::Record') ) 
              ? shift
              : $self->replace_old;
  my %content = @_;
  
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);

  if ( !$error and %content ) {
    $content{'locale'} ||= '';
    my $new_content = qsearchs('template_content', {
                        'msgnum' => $self->msgnum,
                        'locale' => $content{'locale'},
                      } );
    if ( $new_content ) {
      $new_content->subject($content{'subject'});
      $new_content->body($content{'body'});
      $error = $new_content->replace;
    }
    else {
      $content{'msgnum'} = $self->msgnum;
      $new_content = new FS::template_content \%content;
      $error = $new_content->insert;
    }
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  warn "committing FS::msg_template->replace\n" if $DEBUG and $oldAutoCommit;
  $dbh->commit if $oldAutoCommit;
  return;
}

=item content_locales

Returns a hashref of the L<FS::template_content> objects attached to 
this template, with the locale as key.

=cut

sub content_locales {
  my $self = shift;
  return $self->{'_content_locales'} ||= +{
    map { $_->locale , $_ } 
    qsearch('template_content', { 'msgnum' => $self->msgnum })
  };
}

=item prepare OPTION => VALUE

Fills in the template and returns an L<FS::cust_msg> object.

Options are passed as a list of name/value pairs:

=over 4

=item cust_main

Customer object (required).

=item object

Additional context object (currently, can be a cust_main, cust_pkg, 
cust_bill, cust_pay, cust_pay_pending, or svc_(acct, phone, broadband, 
domain) ).  If the object is a svc_*, its cust_pkg will be fetched and 
used for substitution.

As a special case, this may be an arrayref of two objects.  Both 
objects will be available for substitution, with their field names 
prefixed with 'new_' and 'old_' respectively.  This is used in the 
rt_ticket export when exporting "replace" events.

=item from_config

Configuration option to use as the source address, based on the customer's 
agentnum.  If unspecified (or the named option is empty), 'invoice_from' 
will be used.

The I<from_addr> field in the template takes precedence over this.

=item to

Destination address.  The default is to use the customer's 
invoicing_list addresses.  Multiple addresses may be comma-separated.

=item substitutions

A hash reference of additional substitutions

=item msgtype

A string identifying the kind of message this is. Currently can be "invoice", 
"receipt", "admin", or null. Expand this list as necessary.

=back

=cut

sub prepare {

  my( $self, %opt ) = @_;

  my $cust_main = $opt{'cust_main'}; # or die 'cust_main required';
  my $object = $opt{'object'} or die 'object required';

  my $hashref = $self->prepare_substitutions(%opt);

  # localization
  my $locale = $cust_main && $cust_main->locale || '';
  warn "no locale for cust#".$cust_main->custnum."; using default content\n"
    if $DEBUG and $cust_main && !$locale;
  my $content = $self->content($locale);

  warn "preparing template '".$self->msgname."\n"
    if $DEBUG;

  $_ = encode_entities($_ || '') foreach values(%$hashref);

  ###
  # clean up template
  ###
  my $subject_tmpl = new Text::Template (
    TYPE   => 'STRING',
    SOURCE => $content->subject,
  );

  warn "$me filling in subject template\n" if $DEBUG;
  my $subject = $subject_tmpl->fill_in( HASH => $hashref );

  my $body = $content->body;
  my ($skin, $guts) = eviscerate($body);
  @$guts = map { 
    $_ = decode_entities($_); # turn all punctuation back into itself
    s/\r//gs;           # remove \r's
    s/<br[^>]*>/\n/gsi; # and <br /> tags
    s/<p>/\n/gsi;       # and <p>
    s/<\/p>//gsi;       # and </p>
    s/\240/ /gs;        # and &nbsp;
    $_
  } @$guts;
  
  $body = '{ use Date::Format qw(time2str); "" }';
  while(@$skin || @$guts) {
    $body .= shift(@$skin) || '';
    $body .= shift(@$guts) || '';
  }

  ###
  # fill-in
  ###

  my $body_tmpl = new Text::Template (
    TYPE          => 'STRING',
    SOURCE        => $body,
  );
  
  warn "$me filling in body template\n" if $DEBUG;
  $body = $body_tmpl->fill_in( HASH => $hashref );

  ###
  # and email
  ###

  my @to;
  if ( exists($opt{'to'}) ) {
    @to = split(/\s*,\s*/, $opt{'to'});
  } elsif ( $cust_main ) {
    @to = $cust_main->invoicing_list_emailonly;
  } else {
    die 'no To: address or cust_main object specified';
  }

  my $from_addr = $self->from_addr;

  if ( !$from_addr ) {

    my $agentnum = $cust_main ? $cust_main->agentnum : '';

    if ( $opt{'from_config'} ) {
      $from_addr = $conf->config($opt{'from_config'}, $agentnum);
    }
    $from_addr ||= $conf->invoice_from_full($agentnum);
  }

  my $text_body = encode('UTF-8',
                  HTML::FormatText->new(leftmargin => 0, rightmargin => 70)
                      ->format( HTML::TreeBuilder->new_from_content($body) )
                  );

  warn "$me constructing MIME entities\n" if $DEBUG;
  my %email = generate_email(
    'from'      => $from_addr,
    'to'        => \@to,
    'bcc'       => $self->bcc_addr || undef,
    'subject'   => $subject,
    'html_body' => $body,
    'text_body' => $text_body,
  );

  warn "$me creating message headers\n" if $DEBUG;
  my $env_from = $from_addr;
  $env_from =~ s/^\s*//; $env_from =~ s/\s*$//;
  if ( $env_from =~ /^(.*)\s*<(.*@.*)>$/ ) {
    # a common idiom
    $env_from = $2;
  } 
  
  my $domain;
  if ( $env_from =~ /\@([\w\.\-]+)/ ) {
    $domain = $1;
  } else {
    warn 'no domain found in invoice from address '. $env_from .
         '; constructing Message-ID (and saying HELO) @example.com'; 
    $domain = 'example.com';
  } 
  my $message_id = join('.', rand()*(2**32), $$, time). "\@$domain";

  my $time = time;
  my $message = MIME::Entity->build(
    'From'        => $from_addr,
    'To'          => join(', ', @to),
    'Sender'      => $from_addr,
    'Reply-To'    => $from_addr,
    'Date'        => time2str("%a, %d %b %Y %X %z", $time),
    'Subject'     => Encode::encode('MIME-Header', $subject),
    'Message-ID'  => "<$message_id>",
    'Encoding'    => '7bit',
    'Type'        => 'multipart/related',
  );

  #$message->head->replace('Content-type',
  #  'multipart/related; '.
  #  'boundary="' . $message->head->multipart_boundary . '"; ' .
  #  'type=multipart/alternative'
  #);
  
  # XXX a facility to attach additional parts is necessary at some point
  foreach my $part (@{ $email{mimeparts} }) {
    warn "$me appending part ".$part->mime_type."\n" if $DEBUG;
    $message->add_part( $part );
  }

  # effective To: address (not in headers)
  push @to, $self->bcc_addr if $self->bcc_addr;
  my $env_to = join(', ', @to);

  my $cust_msg = FS::cust_msg->new({
      'custnum'   => $cust_main->custnum,
      'msgnum'    => $self->msgnum,
      '_date'     => $time,
      'env_from'  => $env_from,
      'env_to'    => $env_to,
      'header'    => $message->header_as_string,
      'body'      => $message->body_as_string,
      'error'     => '',
      'status'    => 'prepared',
      'msgtype'   => ($opt{'msgtype'} || ''),
      'preview'   => $body, # html content only
  });

  return $cust_msg;
}

=item render OPTION => VALUE ...

Fills in the template and renders it to a PDF document.  Returns the 
name of the PDF file.

Options are as for 'prepare', but 'from' and 'to' are meaningless.

=cut

# will also have options to set paper size, margins, etc.

sub render {
  my $self = shift;
  eval "use PDF::WebKit";
  die $@ if $@;
  my %opt = @_;
  my %hash = $self->prepare(%opt);
  my $html = $hash{'html_body'};

  # Graphics/stylesheets should probably go in /var/www on the Freeside 
  # machine.
  my $script_path = `/usr/bin/which freeside-wkhtmltopdf`;
  chomp $script_path;
  my $kit = PDF::WebKit->new(\$html); #%options
  # hack to use our wrapper script
  $kit->configure(sub { shift->wkhtmltopdf($script_path) });

  $kit->to_pdf;
}

=item print OPTIONS

Render a PDF and send it to the printer.  OPTIONS are as for 'render'.

=cut

sub print {
  my( $self, %opt ) = @_;
  do_print( [ $self->render(%opt) ], agentnum=>$opt{cust_main}->agentnum );
}

# helper sub for package dates
my $ymd = sub { $_[0] ? time2str('%Y-%m-%d', $_[0]) : '' };

# helper sub for money amounts
my $money = sub { ($conf->money_char || '$') . sprintf('%.2f', $_[0] || 0) };

# helper sub for usage-related messages
my $usage_warning = sub {
  my $svc = shift;
  foreach my $col (qw(seconds upbytes downbytes totalbytes)) {
    my $amount = $svc->$col; next if $amount eq '';
    my $method = $col.'_threshold';
    my $threshold = $svc->$method; next if $threshold eq '';
    return [$col, $amount, $threshold] if $amount <= $threshold;
    # this only returns the first one that's below threshold, if there are 
    # several.
  }
  return ['', '', ''];
};

=item content LOCALE

Returns the L<FS::template_content> object appropriate to LOCALE, if there 
is one.  If not, returns the one with a NULL locale.

=cut

sub content {
  my $self = shift;
  my $locale = shift;
  qsearchs('template_content', 
            { 'msgnum' => $self->msgnum, 'locale' => $locale }) || 
  qsearchs('template_content',
            { 'msgnum' => $self->msgnum, 'locale' => '' });
}

=cut

=item send_prepared CUST_MSG

Takes the CUST_MSG object and sends it to its recipient. The "smtpmachine"
configuration option will be used to find the outgoing mail server.

=cut

sub send_prepared {
  my $self = shift;
  my $cust_msg = shift or die "cust_msg required";

  my $domain = 'example.com';
  if ( $cust_msg->env_from =~ /\@([\w\.\-]+)/ ) {
    $domain = $1;
  }

  my @to = split(/\s*,\s*/, $cust_msg->env_to);

  my %smtp_opt = ( 'host' => $conf->config('smtpmachine'),
                   'helo' => $domain );

  my($port, $enc) = split('-', ($conf->config('smtp-encryption') || '25') );
  $smtp_opt{'port'} = $port;
  
  my $transport;
  if ( defined($enc) && $enc eq 'starttls' ) {
    $smtp_opt{$_} = $conf->config("smtp-$_") for qw(username password);
    $transport = Email::Sender::Transport::SMTP::TLS->new( %smtp_opt );
  } else {
    if ( $conf->exists('smtp-username') && $conf->exists('smtp-password') ) {
      $smtp_opt{"sasl_$_"} = $conf->config("smtp-$_") for qw(username password);     
    } 
    $smtp_opt{'ssl'} = 1 if defined($enc) && $enc eq 'tls';
    $transport = Email::Sender::Transport::SMTP->new( %smtp_opt );
  }

  warn "$me sending message\n" if $DEBUG;
  my $message = join("\n\n", $cust_msg->header, $cust_msg->body);
  local $@;
  eval {
    sendmail( $message, { transport => $transport,
                          from      => $cust_msg->env_from,
                          to        => \@to })
  };
  my $error = '';
  if(ref($@) and $@->isa('Email::Sender::Failure')) {
    $error = $@->code.' ' if $@->code;
    $error .= $@->message;
  }
  else {
    $error = $@;
  }

  $cust_msg->set('error', $error);
  $cust_msg->set('status', $error ? 'failed' : 'sent');
  if ( $cust_msg->custmsgnum ) {
    $cust_msg->replace;
  } else {
    $cust_msg->insert;
  }

  $error;
}

=back

=cut

# internal use only

sub eviscerate {
  # Every bit as pleasant as it sounds.
  #
  # We do this because Text::Template::Preprocess doesn't
  # actually work.  It runs the entire template through 
  # the preprocessor, instead of the code segments.  Which 
  # is a shame, because Text::Template already contains
  # the code to do this operation.
  my $body = shift;
  my (@outside, @inside);
  my $depth = 0;
  my $chunk = '';
  while($body || $chunk) {
    my ($first, $delim, $rest);
    # put all leading non-delimiters into $first
    ($first, $rest) =
        ($body =~ /^((?:\\[{}]|[^{}])*)(.*)$/s);
    $chunk .= $first;
    # put a leading delimiter into $delim if there is one
    ($delim, $rest) =
      ($rest =~ /^([{}]?)(.*)$/s);

    if( $delim eq '{' ) {
      $chunk .= '{';
      if( $depth == 0 ) {
        push @outside, $chunk;
        $chunk = '';
      }
      $depth++;
    }
    elsif( $delim eq '}' ) {
      $depth--;
      if( $depth == 0 ) {
        push @inside, $chunk;
        $chunk = '';
      }
      $chunk .= '}';
    }
    else {
      # no more delimiters
      if( $depth == 0 ) {
        push @outside, $chunk . $rest;
      } # else ? something wrong
      last;
    }
    $body = $rest;
  }
  (\@outside, \@inside);
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

