package FS::Misc;

use strict;
use vars qw ( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use Carp;
use FS::Record qw(dbh qsearch);
use FS::cust_credit_refund;
#use FS::cust_credit_bill;
#use FS::cust_bill_pay;
#use FS::cust_pay_refund;
use Data::Dumper;

@ISA = qw( Exporter );
@EXPORT_OK = qw( send_email send_fax
                 states_hash counties state_label
                 card_types prune_applications
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

#this kludges a "mysmtpsend" method into Mail::Internet for send_email above
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
#eokludge

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

=item prune_applications OPTION_HASH

Removes applications of credits to refunds in the event that the database
is corrupt and either the credits or refunds are missing (see
L<FS::cust_credit>, L<FS::cust_refund>, and L<FS::cust_credit_refund>).
If the OPTION_HASH contains the element 'dry_run' then a report of
affected records is returned rather than actually deleting the records.

=cut

sub prune_applications {
  my $options = shift;
  my $dbh = dbh

  local $DEBUG = 1 if exists($options->{debug});
  my $ccr = <<EOW;
    WHERE
         0 = (select count(*) from cust_credit
               where cust_credit_refund.crednum = cust_credit.crednum)
      or 
         0 = (select count(*) from cust_refund
               where cust_credit_refund.refundnum = cust_refund.refundnum)
EOW
  my $ccb = <<EOW;
    WHERE
         0 = (select count(*) from cust_credit
               where cust_credit_bill.crednum = cust_credit.crednum)
      or 
         0 = (select count(*) from cust_bill
               where cust_credit_bill.invnum = cust_bill.invnum)
EOW
  my $cbp = <<EOW;
    WHERE
         0 = (select count(*) from cust_bill
               where cust_bill_pay.invnum = cust_bill.invnum)
      or 
         0 = (select count(*) from cust_pay
               where cust_bill_pay.paynum = cust_pay.paynum)
EOW
  my $cpr = <<EOW;
    WHERE
         0 = (select count(*) from cust_pay
               where cust_pay_refund.paynum = cust_pay.paynum)
      or 
         0 = (select count(*) from cust_refund
               where cust_pay_refund.refundnum = cust_refund.refundnum)
EOW

  my %strays = (
    'cust_credit_refund' => { clause => $ccr,
                              link1  => 'crednum',
                              link2  => 'refundnum',
                            },
#    'cust_credit_bill'   => { clause => $ccb,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
#    'cust_bill_pay'      => { clause => $cbp,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
#    'cust_pay_refund'    => { clause => $cpr,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
  );

  if ( exists($options->{dry_run}) ) {
    my @response = ();
    foreach my $table (keys %strays) {
      my $clause = $strays{$table}->{clause};
      my $link1  = $strays{$table}->{link1};
      my $link2  = $strays{$table}->{link2};
      my @rec = qsearch($table, {}, '', $clause);
      my $keyname = $rec[0]->primary_key if $rec[0];
      foreach (@rec) {
        push @response, "$table " .$_->$keyname . " claims attachment to ".
               "$link1 " . $_->$link1 . " and $link2 " . $_->$link2 . "\n";
      }
    }
    return (@response);
  } else {
    foreach (keys %strays) {
      my $statement = "DELETE FROM $_ " . $strays{$_}->{clause};
      warn $statement if $DEBUG;
      my $sth = $dbh->prepare($statement)
        or die $dbh->errstr;
      $sth->execute
        or die $sth->errstr;
    }
    return ();
  }
}

=back

=head1 BUGS

This package exists.

=head1 SEE ALSO

L<FS::UID>, L<FS::CGI>, L<FS::Record>, the base documentation.

L<Fax::Hylafax::Client>

=cut

1;
