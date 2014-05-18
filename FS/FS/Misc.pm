package FS::Misc;

use strict;
use vars qw ( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use Carp;
use Data::Dumper;
use IPC::Run qw( run timeout );   # for _pslatex
use IPC::Run3; # for do_print... should just use IPC::Run i guess
use File::Temp;
use Tie::IxHash;
use Encode;
#do NOT depend on any FS:: modules here, causes weird (sometimes unreproducable
#until on client machine) dependancy loops.  put them in FS::Misc::Something
#instead

@ISA = qw( Exporter );
@EXPORT_OK = qw( send_email generate_email send_fax
                 states_hash counties cities state_label
                 card_types
                 pkg_freqs
                 generate_ps generate_pdf do_print
                 csv_from_fixed
                 ocr_image
               );

$DEBUG = 0;

=head1 NAME

FS::Misc - Miscellaneous subroutines

=head1 SYNOPSIS

  use FS::Misc qw(send_email);

  send_email();

=head1 DESCRIPTION

Miscellaneous subroutines.  This module contains miscellaneous subroutines
called from multiple other modules.  These are not OO or necessarily related,
but are collected here to eliminate code duplication.

=head1 SUBROUTINES

=over 4

=item send_email OPTION => VALUE ...

Options:

=over 4

=item from

(required)

=item to

(required) comma-separated scalar or arrayref of recipients

=item subject

(required)

=item content-type

(optional) MIME type for the body

=item body

(required unless I<nobody> is true) arrayref of body text lines

=item mimeparts

(optional, but required if I<nobody> is true) arrayref of MIME::Entity->build PARAMHASH refs or MIME::Entity objects.  These will be passed as arguments to MIME::Entity->attach().

=item nobody

(optional) when set true, send_email will ignore the I<body> option and simply construct a message with the given I<mimeparts>.  In this case,
I<content-type>, if specified, overrides the default "multipart/mixed" for the outermost MIME container.

=item content-encoding

(optional) when using nobody, optional top-level MIME
encoding which, if specified, overrides the default "7bit".

=item type

(optional) type parameter for multipart/related messages

=item custnum

(optional) L<FS::cust_main> key; if passed, the message will be logged
(if logging is enabled) with this custnum.

=item msgnum

(optional) L<FS::msg_template> key, for logging.

=back

=cut

use vars qw( $conf );
use Date::Format;
use MIME::Entity;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Email::Sender::Transport::SMTP::TLS 0.11;
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

  my @to = ref($options{to}) ? @{ $options{to} } : ( $options{to} );

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
        'Charset'     => 'UTF-8',
        'Data'        => $options{'body'},
        'Encoding'    => ( $options{'content-type'} ? '-SUGGEST' : '7bit' ),
        'Disposition' => 'inline',
      };

    } else {
    
      @mimeargs = (
        'Type'     => ( $options{'content-type'} || 'text/plain' ),
        'Data'     => $options{'body'},
        'Encoding' => ( $options{'content-type'} ? '-SUGGEST' : '7bit' ),
        'Charset'  => 'UTF-8',
      );

    }

  }

  my $from = $options{from};
  $from =~ s/^\s*//; $from =~ s/\s*$//;
  if ( $from =~ /^(.*)\s*<(.*@.*)>$/ ) {
    # a common idiom
    $from = $2;
  }

  my $domain;
  if ( $from =~ /\@([\w\.\-]+)/ ) {
    $domain = $1;
  } else {
    warn 'no domain found in invoice from address '. $options{'from'}.
         '; constructing Message-ID (and saying HELO) @example.com'; 
    $domain = 'example.com';
  }
  my $message_id = join('.', rand()*(2**32), $$, time). "\@$domain";

  my $time = time;
  my $message = MIME::Entity->build(
    'From'       => $options{'from'},
    'To'         => join(', ', @to),
    'Sender'     => $options{'from'},
    'Reply-To'   => $options{'from'},
    'Date'       => time2str("%a, %d %b %Y %X %z", $time),
    'Subject'    => Encode::encode('MIME-Header', $options{'subject'}),
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

  #send the email

  my %smtp_opt = ( 'host' => $conf->config('smtpmachine'),
                   'helo' => $domain,
                 );

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
  
  push @to, $options{bcc} if defined($options{bcc});
  local $@; # just in case
  eval { sendmail($message, { transport => $transport,
                              from      => $from,
                              to        => \@to }) };

  my $error = '';
  if(ref($@) and $@->isa('Email::Sender::Failure')) {
    $error = $@->code.' ' if $@->code;
    $error .= $@->message;
  }
  else {
    $error = $@;
  }

  # Logging
  if ( $conf->exists('log_sent_mail') ) {
    my $cust_msg = FS::cust_msg->new({
        'env_from'  => $options{'from'},
        'env_to'    => join(', ', @to),
        'header'    => $message->header_as_string,
        'body'      => $message->body_as_string,
        '_date'     => $time,
        'error'     => $error,
        'custnum'   => $options{'custnum'},
        'msgnum'    => $options{'msgnum'},
        'status'    => ($error ? 'failed' : 'sent'),
        'msgtype'   => $options{'msgtype'},
    });
    $cust_msg->insert; # ignore errors
  }
  $error;
   
}

=item generate_email OPTION => VALUE ...

Options:

=over 4

=item from

Sender address, required

=item to

Recipient address, required

=item bcc

Blind copy address, optional

=item subject

email subject, required

=item html_body

Email body (HTML alternative).  Arrayref of lines, or scalar.

Will be placed inside an HTML <BODY> tag.

=item text_body

Email body (Text alternative).  Arrayref of lines, or scalar.

=item custnum, msgnum (optional)

Customer and template numbers, passed through to send_email for logging.

=back

Constructs a multipart message from text_body and html_body.

=cut

#false laziness w/FS::cust_bill::generate_email

use MIME::Entity;
use HTML::Entities;

sub generate_email {
  my %args = @_;

  my $me = '[FS::Misc::generate_email]';

  my @fields = qw(from to bcc subject custnum msgnum msgtype);
  my %return;
  @return{@fields} = @args{@fields};

  warn "$me creating HTML/text multipart message"
    if $DEBUG;

  $return{'nobody'} = 1;

  my $alternative = build MIME::Entity
    'Type'        => 'multipart/alternative',
    'Encoding'    => '7bit',
    'Disposition' => 'inline'
  ;

  my $data;
  if ( ref($args{'text_body'}) eq 'ARRAY' ) {
    $data = join("\n", @{ $args{'text_body'} });
  } else {
    $data = $args{'text_body'};
  }

  $alternative->attach(
    'Type'        => 'text/plain',
    'Encoding'    => 'quoted-printable',
    'Charset'     => 'UTF-8',
    #'Encoding'    => '7bit',
    'Data'        => $data,
    'Disposition' => 'inline',
  );

  my @html_data;
  if ( ref($args{'html_body'}) eq 'ARRAY' ) {
    @html_data = @{ $args{'html_body'} };
  } else {
    @html_data = split(/\n/, $args{'html_body'});
  }

  $alternative->attach(
    'Type'        => 'text/html',
    'Encoding'    => 'quoted-printable',
    'Data'        => [ '<html>',
                       '  <head>',
                       '    <title>',
                       '      '. encode_entities($return{'subject'}), 
                       '    </title>',
                       '  </head>',
                       '  <body bgcolor="#ffffff">',
                       @html_data,
                       '  </body>',
                       '</html>',
                     ],
    'Disposition' => 'inline',
    #'Filename'    => 'invoice.pdf',
  );

  #no other attachment:
  # multipart/related
  #   multipart/alternative
  #     text/plain
  #     text/html

  $return{'content-type'} = 'multipart/related';
  $return{'mimeparts'} = [ $alternative ];
  $return{'type'} = 'multipart/alternative'; #Content-Type of first part...
  #$return{'disposition'} = 'inline';

  %return;

}

=item process_send_email OPTION => VALUE ...

Takes arguments as per generate_email() and sends the message.  This 
will die on any error and can be used in the job queue.

=cut

sub process_send_email {
  my %message = @_;
  my $error = send_email(generate_email(%message));
  die "$error\n" if $error;
  '';
}

=item process_send_generated_email OPTION => VALUE ...

Takes arguments as per send_email() and sends the message.  This 
will die on any error and can be used in the job queue.

=cut

sub process_send_generated_email {
  my %args = @_;
  my $error = send_email(%args);
  die "$error\n" if $error;
  '';
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
      my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
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

=item states_hash COUNTRY

Returns a list of key/value pairs containing state (or other sub-country
division) abbriviations and names.

=cut

use FS::Record qw(qsearch);
use Locale::SubCountry;

sub states_hash {
  my($country) = @_;

  my @states = 
#     sort
     map { s/[\n\r]//g; $_; }
     map { $_->state; }
         qsearch({ 
                   'select'    => 'state',
                   'table'     => 'cust_main_county',
                   'hashref'   => { 'country' => $country },
                   'extra_sql' => 'GROUP BY state',
                });

  #it could throw a fatal "Invalid country code" error (for example "AX")
  my $subcountry = eval { new Locale::SubCountry($country) }
    or return ( '', '(n/a)' );

  #"i see your schwartz is as big as mine!"
  map  { ( $_->[0] => $_->[1] ) }
  sort { $a->[1] cmp $b->[1] }
  map  { [ $_ => state_label($_, $subcountry) ] }
       @states;
}

=item counties STATE COUNTRY

Returns a list of counties for this state and country.

=cut

sub counties {
  my( $state, $country ) = @_;

  map { $_ } #return num_counties($state, $country) unless wantarray;
  sort map { s/[\n\r]//g; $_; }
       map { $_->county }
           qsearch({
             'select'  => 'DISTINCT county',
             'table'   => 'cust_main_county',
             'hashref' => { 'state'   => $state,
                            'country' => $country,
                          },
           });
}

=item cities COUNTY STATE COUNTRY

Returns a list of cities for this county, state and country.

=cut

sub cities {
  my( $county, $state, $country ) = @_;

  map { $_ } #return num_cities($county, $state, $country) unless wantarray;
  sort map { s/[\n\r]//g; $_; }
       map { $_->city }
           qsearch({
             'select'  => 'DISTINCT city',
             'table'   => 'cust_main_county',
             'hashref' => { 'county'  => $county,
                            'state'   => $state,
                            'country' => $country,
                          },
           });
}

=item state_label STATE COUNTRY_OR_LOCALE_SUBCOUNRY_OBJECT

=cut

sub state_label {
  my( $state, $country ) = @_;

  unless ( ref($country) ) {
    $country = eval { new Locale::SubCountry($country) }
      or return'(n/a)';

  }

  # US kludge to avoid changing existing behaviour 
  # also we actually *use* the abbriviations...
  my $full_name = $country->country_code eq 'US'
                    ? ''
                    : $country->full_name($state);

  $full_name = '' if $full_name eq 'unknown';
  $full_name =~ s/\(see also.*\)\s*$//;
  $full_name .= " ($state)" if $full_name;

  $full_name || $state || '(n/a)';

}

=item card_types

Returns a hash reference of the accepted credit card types.  Keys are shorter
identifiers and values are the longer strings used by the system (see
L<Business::CreditCard>).

=cut

#$conf from above

sub card_types {
  my $conf = new FS::Conf;

  my %card_types = (
    #displayname                    #value (Business::CreditCard)
    "VISA"                       => "VISA card",
    "MasterCard"                 => "MasterCard",
    "Discover"                   => "Discover card",
    "American Express"           => "American Express card",
    "Diner's Club/Carte Blanche" => "Diner's Club/Carte Blanche",
    "enRoute"                    => "enRoute",
    "JCB"                        => "JCB",
    "BankCard"                   => "BankCard",
    "Switch"                     => "Switch",
    "Solo"                       => "Solo",
  );
  my @conf_card_types = grep { ! /^\s*$/ } $conf->config('card-types');
  if ( @conf_card_types ) {
    #perhaps the hash is backwards for this, but this way works better for
    #usage in selfservice
    %card_types = map  { $_ => $card_types{$_} }
                  grep {
                         my $d = $_;
			   grep { $card_types{$d} eq $_ } @conf_card_types
                       }
		    keys %card_types;
  }

  \%card_types;
}

=item pkg_freqs

Returns a hash reference of allowed package billing frequencies.

=cut

sub pkg_freqs {
  tie my %freq, 'Tie::IxHash', (
    '0'    => '(no recurring fee)',
    '1h'   => 'hourly',
    '1d'   => 'daily',
    '2d'   => 'every two days',
    '3d'   => 'every three days',
    '1w'   => 'weekly',
    '2w'   => 'biweekly (every 2 weeks)',
    '1'    => 'monthly',
    '45d'  => 'every 45 days',
    '2'    => 'bimonthly (every 2 months)',
    '3'    => 'quarterly (every 3 months)',
    '4'    => 'every 4 months',
    '137d' => 'every 4 1/2 months (137 days)',
    '6'    => 'semiannually (every 6 months)',
    '12'   => 'annually',
    '13'   => 'every 13 months (annually +1 month)',
    '24'   => 'biannually (every 2 years)',
    '36'   => 'triannually (every 3 years)',
    '48'   => '(every 4 years)',
    '60'   => '(every 5 years)',
    '120'  => '(every 10 years)',
  ) ;
  \%freq;
}

=item generate_ps FILENAME

Returns an postscript rendition of the LaTex file, as a scalar.
FILENAME does not contain the .tex suffix and is unlinked by this function.

=cut

use String::ShellQuote;

sub generate_ps {
  my $file = shift;

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  chdir($dir);

  _pslatex($file);

  system('dvips', '-q', '-t', 'letter', "$file.dvi", '-o', "$file.ps" ) == 0
    or die "dvips failed";

  open(POSTSCRIPT, "<$file.ps")
    or die "can't open $file.ps: $! (error in LaTeX template?)\n";

  unlink("$file.dvi", "$file.log", "$file.aux", "$file.ps", "$file.tex")
    unless $FS::CurrentUser::CurrentUser->option('save_tmp_typesetting');

  my $ps = '';

  if ( $conf->exists('lpr-postscript_prefix') ) {
    my $prefix = $conf->config('lpr-postscript_prefix');
    $ps .= eval qq("$prefix");
  }

  while (<POSTSCRIPT>) {
    $ps .= $_;
  }

  close POSTSCRIPT;

  if ( $conf->exists('lpr-postscript_suffix') ) {
    my $suffix = $conf->config('lpr-postscript_suffix');
    $ps .= eval qq("$suffix");
  }

  return $ps;

}

=item generate_pdf FILENAME

Returns an PDF rendition of the LaTex file, as a scalar.  FILENAME does not
contain the .tex suffix and is unlinked by this function.

=cut

use String::ShellQuote;

sub generate_pdf {
  my $file = shift;

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  chdir($dir);

  #system('pdflatex', "$file.tex");
  #system('pdflatex', "$file.tex");
  #! LaTeX Error: Unknown graphics extension: .eps.

  _pslatex($file);

  my $sfile = shell_quote $file;

  #system('dvipdf', "$file.dvi", "$file.pdf" );
  system(
    "dvips -q -t letter -f $sfile.dvi ".
    "| gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$sfile.pdf ".
    "     -c save pop -"
  ) == 0
    or die "dvips | gs failed: $!";

  open(PDF, "<$file.pdf")
    or die "can't open $file.pdf: $! (error in LaTeX template?)\n";

  unlink("$file.dvi", "$file.log", "$file.aux", "$file.pdf", "$file.tex")
    unless $FS::CurrentUser::CurrentUser->option('save_tmp_typesetting');

  my $pdf = '';
  while (<PDF>) {
    $pdf .= $_;
  }

  close PDF;

  return $pdf;

}

sub _pslatex {
  my $file = shift;

  #my $sfile = shell_quote $file;

  my @cmd = (
    'latex',
    '-interaction=batchmode',
    '\AtBeginDocument{\RequirePackage{pslatex}}',
    '\def\PSLATEXTMP{\futurelet\PSLATEXTMP\PSLATEXTMPB}',
    '\def\PSLATEXTMPB{\ifx\PSLATEXTMP\nonstopmode\else\input\fi}',
    '\PSLATEXTMP',
    "$file.tex"
  );

  my $timeout = 30; #? should be more than enough

  for ( 1, 2 ) {

    local($SIG{CHLD}) = sub {};
    run( \@cmd, '>'=>'/dev/null', '2>'=>'/dev/null', timeout($timeout) )
      or warn "bad exit status from pslatex pass $_\n";

  }

  return if -e "$file.dvi" && -s "$file.dvi";
  die "pslatex $file.tex failed; see $file.log for details?\n";

}

=item do_print ARRAYREF [, OPTION => VALUE ... ]

Sends the lines in ARRAYREF to the printer.

Options available are:

=over 4

=item agentnum

Uses this agent's 'lpr' configuration setting override instead of the global
value.

=item lpr

Uses this command instead of the configured lpr command (overrides both the
global value and agentnum).

=cut

sub do_print {
  my( $data, %opt ) = @_;

  my $lpr = ( exists($opt{'lpr'}) && $opt{'lpr'} )
              ? $opt{'lpr'}
              : $conf->config('lpr', $opt{'agentnum'} );

  my $outerr = '';
  run3 $lpr, $data, \$outerr, \$outerr;
  if ( $? ) {
    $outerr = ": $outerr" if length($outerr);
    die "Error from $lpr (exit status ". ($?>>8). ")$outerr\n";
  }

}

=item csv_from_fixed, FILEREF COUNTREF, [ LENGTH_LISTREF, [ CALLBACKS_LISTREF ] ]

Converts the filehandle referenced by FILEREF from fixed length record
lines to a CSV file according to the lengths specified in LENGTH_LISTREF.
The CALLBACKS_LISTREF refers to a correpsonding list of coderefs.  Each
should return the value to be substituted in place of its single argument.

Returns false on success or an error if one occurs.

=cut

sub csv_from_fixed {
  my( $fhref, $countref, $lengths, $callbacks) = @_;

  eval { require Text::CSV_XS; };
  return $@ if $@;

  my $ofh = $$fhref;
  my $unpacker = new Text::CSV_XS;
  my $total = 0;
  my $template = join('', map {$total += $_; "A$_"} @$lengths) if $lengths;

  my $dir = "%%%FREESIDE_CACHE%%%/cache.$FS::UID::datasrc";
  my $fh = new File::Temp( TEMPLATE => "FILE.csv.XXXXXXXX",
                           DIR      => $dir,
                           UNLINK   => 0,
                         ) or return "can't open temp file: $!\n"
    if $template;

  while ( defined(my $line=<$ofh>) ) {
    $$countref++;
    if ( $template ) {
      my $column = 0;

      chomp $line;
      return "unexpected input at line $$countref: $line".
             " -- expected $total but received ". length($line)
        unless length($line) == $total;

      $unpacker->combine( map { my $i = $column++;
                                defined( $callbacks->[$i] )
                                  ? &{ $callbacks->[$i] }( $_ )
                                  : $_
                              } unpack( $template, $line )
                        )
        or return "invalid data for CSV: ". $unpacker->error_input;

      print $fh $unpacker->string(), "\n"
        or return "can't write temp file: $!\n";
    }
  }

  if ( $template ) { close $$fhref; $$fhref = $fh }

  seek $$fhref, 0, 0;
  '';
}

=item ocr_image IMAGE_SCALAR

Runs OCR on the provided image data and returns a list of text lines.

=cut

sub ocr_image {
  my $logo_data = shift;

  #XXX use conf dir location from Makefile
  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  my $fh = new File::Temp(
    TEMPLATE => 'bizcard.XXXXXXXX',
    SUFFIX   => '.png', #XXX assuming, but should handle jpg, gif, etc. too
    DIR      => $dir,
    UNLINK   => 0,
  ) or die "can't open temp file: $!\n";

  my $filename = $fh->filename;

  print $fh $logo_data;
  close $fh;

  run( [qw(ocroscript recognize), $filename], '>'=>"$filename.hocr" )
    or die "ocroscript recognize failed\n";

  run( [qw(ocroscript hocr-to-text), "$filename.hocr"], '>pipe'=>\*OUT )
    or die "ocroscript hocr-to-text failed\n";

  my @lines = split(/\n/, <OUT> );

  foreach (@lines) { s/\.c0m\s*$/.com/; }

  @lines;
}

=back

=head1 BUGS

This package exists.

=head1 SEE ALSO

L<FS::UID>, L<FS::CGI>, L<FS::Record>, the base documentation.

L<Fax::Hylafax::Client>

=cut

1;
