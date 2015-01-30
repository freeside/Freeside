package FS::msg_template;
use base qw( FS::Record );

use strict;
use vars qw( $DEBUG $conf );

use Date::Format qw( time2str );
use File::Temp;
use IPC::Run qw(run);
use Text::Template;

use HTML::Entities qw( decode_entities encode_entities ) ;
use HTML::FormatText;
use HTML::TreeBuilder;
use Encode;

use FS::Misc qw( generate_email send_email do_print );
use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::UID qw( dbh );

use FS::cust_main;
use FS::cust_msg;
use FS::template_content;

FS::UID->install_callback( sub { $conf = new FS::Conf; } );

$DEBUG=0;

=head1 NAME

FS::msg_template - Object methods for msg_template records

=head1 SYNOPSIS

  use FS::msg_template;

  $record = new FS::msg_template \%hash;
  $record = new FS::msg_template { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::msg_template object represents a customer message template.
FS::msg_template inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item msgnum - primary key

=item msgname - Name of the template.  This will appear in the user interface;
if it needs to be localized for some users, add it to the message catalog.

=item agentnum - Agent associated with this template.  Can be NULL for a 
global template.

=item mime_type - MIME type.  Defaults to text/html.

=item from_addr - Source email address.

=item disabled - disabled ('Y' or NULL).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new template.  To add the template to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'msg_template'; }

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

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

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
    


=item check

Checks all fields to make sure this is a valid template.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('msgnum')
    || $self->ut_text('msgname')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_textn('mime_type')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_textn('from_addr')
  ;
  return $error if $error;

  $self->mime_type('text/html') unless $self->mime_type;

  $self->SUPER::check;
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

Fills in the template and returns a hash of the 'from' address, 'to' 
addresses, subject line, and body.

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

=back

=cut

sub prepare {
  my( $self, %opt ) = @_;

  my $cust_main = $opt{'cust_main'} or die 'cust_main required';
  my $object = $opt{'object'} or die 'object required';

  # localization
  my $locale = $cust_main->locale || '';
  warn "no locale for cust#".$cust_main->custnum."; using default content\n"
    if $DEBUG and !$locale;
  my $content = $self->content($cust_main->locale);
  warn "preparing template '".$self->msgname."' to cust#".$cust_main->custnum."\n"
    if($DEBUG);

  my $subs = $self->substitutions;

  ###
  # create substitution table
  ###  
  my %hash;
  my @objects = ($cust_main);
  my @prefixes = ('');
  my $svc;
  if( ref $object ) {
    if( ref($object) eq 'ARRAY' ) {
      # [new, old], for provisioning tickets
      push @objects, $object->[0], $object->[1];
      push @prefixes, 'new_', 'old_';
      $svc = $object->[0] if $object->[0]->isa('FS::svc_Common');
    }
    else {
      push @objects, $object;
      push @prefixes, '';
      $svc = $object if $object->isa('FS::svc_Common');
    }
  }
  if( $svc ) {
    push @objects, $svc->cust_svc->cust_pkg;
    push @prefixes, '';
  }

  foreach my $obj (@objects) {
    my $prefix = shift @prefixes;
    foreach my $name (@{ $subs->{$obj->table} }) {
      if(!ref($name)) {
        # simple case
        $hash{$prefix.$name} = $obj->$name();
      }
      elsif( ref($name) eq 'ARRAY' ) {
        # [ foo => sub { ... } ]
        $hash{$prefix.($name->[0])} = $name->[1]->($obj);
      }
      else {
        warn "bad msg_template substitution: '$name'\n";
        #skip it?
      } 
    } 
  } 

  if ( $opt{substitutions} ) {
    $hash{$_} = $opt{substitutions}->{$_} foreach keys %{$opt{substitutions}};
  }

  $_ = encode_entities($_ || '') foreach values(%hash);

  ###
  # clean up template
  ###
  my $subject_tmpl = new Text::Template (
    TYPE   => 'STRING',
    SOURCE => $content->subject,
  );
  my $subject = $subject_tmpl->fill_in( HASH => \%hash );

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

  $body = $body_tmpl->fill_in( HASH => \%hash );

  ###
  # and email
  ###

  my @to;
  if ( exists($opt{'to'}) ) {
    @to = split(/\s*,\s*/, $opt{'to'});
  }
  else {
    @to = $cust_main->invoicing_list_emailonly;
  }
  # no warning when preparing with no destination

  my $from_addr = $self->from_addr;

  if ( !$from_addr ) {
    if ( $opt{'from_config'} ) {
      $from_addr = scalar( $conf->config($opt{'from_config'}, 
                                         $cust_main->agentnum) );
    }
    $from_addr ||= $conf->invoice_from_full($cust_main->agentnum);
  }
#  my @cust_msg = ();
#  if ( $conf->exists('log_sent_mail') and !$opt{'preview'} ) {
#    my $cust_msg = FS::cust_msg->new({
#        'custnum' => $cust_main->custnum,
#        'msgnum'  => $self->msgnum,
#        'status'  => 'prepared',
#      });
#    $cust_msg->insert;
#    @cust_msg = ('cust_msg' => $cust_msg);
#  }

  my $text_body = encode('UTF-8',
                  HTML::FormatText->new(leftmargin => 0, rightmargin => 70)
                      ->format( HTML::TreeBuilder->new_from_content($body) )
                  );
  (
    'custnum' => $cust_main->custnum,
    'msgnum'  => $self->msgnum,
    'from' => $from_addr,
    'to'   => \@to,
    'bcc'  => $self->bcc_addr || undef,
    'subject'   => $subject,
    'html_body' => $body,
    'text_body' => $text_body
  );

}

=item send OPTION => VALUE

Fills in the template and sends it to the customer.  Options are as for 
'prepare'.

=cut

# broken out from prepare() in case we want to queue the sending,
# preview it, etc.
sub send {
  my $self = shift;
  send_email(generate_email($self->prepare(@_)));
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
  my $kit = PDF::WebKit->new(\$html); #%options
  # hack to use our wrapper script
  $kit->configure(sub { shift->wkhtmltopdf('freeside-wkhtmltopdf') });

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

#my $conf = new FS::Conf;

#return contexts and fill-in values
# If you add anything, be sure to add a description in 
# httemplate/edit/msg_template.html.
sub substitutions {
  { 'cust_main' => [qw(
      display_custnum agentnum agent_name

      last first company
      name name_short contact contact_firstlast
      address1 address2 city county state zip
      country
      daytime night mobile fax

      has_ship_address
      ship_name ship_name_short ship_contact ship_contact_firstlast
      ship_address1 ship_address2 ship_city ship_county ship_state ship_zip
      ship_country

      paymask payname paytype payip
      num_cancelled_pkgs num_ncancelled_pkgs num_pkgs
      classname categoryname
      balance
      credit_limit
      invoicing_list_emailonly
      cust_status ucfirst_cust_status cust_statuscolor cust_status_label

      signupdate dundate
      packages recurdates
      ),
      [ invoicing_email => sub { shift->invoicing_list_emailonly_scalar } ],
      #compatibility: obsolete ship_ fields - use the non-ship versions
      map (
        { my $field = $_;
          [ "ship_$field"   => sub { shift->$field } ]
        }
        qw( last first company daytime night fax )
      ),
      # ship_name, ship_name_short, ship_contact, ship_contact_firstlast
      # still work, though
      [ expdate           => sub { shift->paydate_epoch } ], #compatibility
      [ signupdate_ymd    => sub { $ymd->(shift->signupdate) } ],
      [ dundate_ymd       => sub { $ymd->(shift->dundate) } ],
      [ paydate_my        => sub { sprintf('%02d/%04d', shift->paydate_monthyear) } ],
      [ otaker_first      => sub { shift->access_user->first } ],
      [ otaker_last       => sub { shift->access_user->last } ],
      [ payby             => sub { FS::payby->shortname(shift->payby) } ],
      [ company_name      => sub { 
          $conf->config('company_name', shift->agentnum) 
        } ],
      [ company_address   => sub {
          $conf->config('company_address', shift->agentnum)
        } ],
      [ company_phonenum  => sub {
          $conf->config('company_phonenum', shift->agentnum)
        } ],
      [ selfservice_server_base_url => sub { 
          $conf->config('selfservice_server-base_url') #, shift->agentnum) 
        } ],
    ],
    # next_bill_date
    'cust_pkg'  => [qw( 
      pkgnum pkg_label pkg_label_long
      location_label
      status statuscolor
    
      start_date setup bill last_bill 
      adjourn susp expire 
      labels_short
      ),
      [ pkg               => sub { shift->part_pkg->pkg } ],
      [ pkg_category      => sub { shift->part_pkg->categoryname } ],
      [ pkg_class         => sub { shift->part_pkg->classname } ],
      [ cancel            => sub { shift->getfield('cancel') } ], # grrr...
      [ start_ymd         => sub { $ymd->(shift->getfield('start_date')) } ],
      [ setup_ymd         => sub { $ymd->(shift->getfield('setup')) } ],
      [ next_bill_ymd     => sub { $ymd->(shift->getfield('bill')) } ],
      [ last_bill_ymd     => sub { $ymd->(shift->getfield('last_bill')) } ],
      [ adjourn_ymd       => sub { $ymd->(shift->getfield('adjourn')) } ],
      [ susp_ymd          => sub { $ymd->(shift->getfield('susp')) } ],
      [ expire_ymd        => sub { $ymd->(shift->getfield('expire')) } ],
      [ cancel_ymd        => sub { $ymd->(shift->getfield('cancel')) } ],

      # not necessarily correct for non-flat packages
      [ setup_fee         => sub { shift->part_pkg->option('setup_fee') } ],
      [ recur_fee         => sub { shift->part_pkg->option('recur_fee') } ],

      [ freq_pretty       => sub { shift->part_pkg->freq_pretty } ],

    ],
    'cust_bill' => [qw(
      invnum
      _date
      _date_pretty
      due_date
      due_date2str
    )],
    #XXX not really thinking about cust_bill substitutions quite yet
    
    # for welcome and limit warning messages
    'svc_acct' => [qw(
      svcnum
      username
      domain
      ),
      [ password          => sub { shift->getfield('_password') } ],
      [ column            => sub { &$usage_warning(shift)->[0] } ],
      [ amount            => sub { &$usage_warning(shift)->[1] } ],
      [ threshold         => sub { &$usage_warning(shift)->[2] } ],
    ],
    'svc_domain' => [qw(
      svcnum
      domain
      ),
      [ registrar         => sub {
          my $registrar = qsearchs('registrar', 
            { registrarnum => shift->registrarnum} );
          $registrar ? $registrar->registrarname : ''
        }
      ],
      [ catchall          => sub { 
          my $svc_acct = qsearchs('svc_acct', { svcnum => shift->catchall });
          $svc_acct ? $svc_acct->email : ''
        }
      ],
    ],
    'svc_phone' => [qw(
      svcnum
      phonenum
      countrycode
      domain
      )
    ],
    'svc_broadband' => [qw(
      svcnum
      speed_up
      speed_down
      ip_addr
      mac_addr
      )
    ],
    # for payment receipts
    'cust_pay' => [qw(
      paynum
      _date
      ),
      [ paid              => sub { sprintf("%.2f", shift->paid) } ],
      # overrides the one in cust_main in cases where a cust_pay is passed
      [ payby             => sub { FS::payby->shortname(shift->payby) } ],
      [ date              => sub { time2str("%a %B %o, %Y", shift->_date) } ],
      [ payinfo           => sub { 
          my $cust_pay = shift;
          ($cust_pay->payby eq 'CARD' || $cust_pay->payby eq 'CHEK') ?
            $cust_pay->paymask : $cust_pay->decrypt($cust_pay->payinfo)
        } ],
    ],
    # for payment decline messages
    # try to support all cust_pay fields
    # 'error' is a special case, it contains the raw error from the gateway
    'cust_pay_pending' => [qw(
      _date
      error
      ),
      [ paid              => sub { sprintf("%.2f", shift->paid) } ],
      [ payby             => sub { FS::payby->shortname(shift->payby) } ],
      [ date              => sub { time2str("%a %B %o, %Y", shift->_date) } ],
      [ payinfo           => sub {
          my $pending = shift;
          ($pending->payby eq 'CARD' || $pending->payby eq 'CHEK') ?
            $pending->paymask : $pending->decrypt($pending->payinfo)
        } ],
    ],
  };
}

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

=item agent

Returns the L<FS::agent> object for this template.

=cut

sub _upgrade_data {
  my ($self, %opts) = @_;

  ###
  # First move any historical templates in config to real message templates
  ###

  my @fixes = (
    [ 'alerter_msgnum',  'alerter_template',   '',               '', '' ],
    [ 'cancel_msgnum',   'cancelmessage',      'cancelsubject',  '', '' ],
    [ 'decline_msgnum',  'declinetemplate',    '',               '', '' ],
    [ 'impending_recur_msgnum', 'impending_recur_template', '',  '', 'impending_recur_bcc' ],
    [ 'payment_receipt_msgnum', 'payment_receipt_email', '',     '', '' ],
    [ 'welcome_msgnum',  'welcome_email',      'welcome_email-subject', 'welcome_email-from', '' ],
    [ 'warning_msgnum',  'warning_email',      'warning_email-subject', 'warning_email-from', '' ],
  );
 
  my @agentnums = ('', map {$_->agentnum} qsearch('agent', {}));
  foreach my $agentnum (@agentnums) {
    foreach (@fixes) {
      my ($newname, $oldname, $subject, $from, $bcc) = @$_;
      if ($conf->exists($oldname, $agentnum)) {
        my $new = new FS::msg_template({
          'msgname'   => $oldname,
          'agentnum'  => $agentnum,
          'from_addr' => ($from && $conf->config($from, $agentnum)) || '',
          'bcc_addr'  => ($bcc && $conf->config($from, $agentnum)) || '',
          'subject'   => ($subject && $conf->config($subject, $agentnum)) || '',
          'mime_type' => 'text/html',
          'body'      => join('<BR>',$conf->config($oldname, $agentnum)),
        });
        my $error = $new->insert;
        die $error if $error;
        $conf->set($newname, $new->msgnum, $agentnum);
        $conf->delete($oldname, $agentnum);
        $conf->delete($from, $agentnum) if $from;
        $conf->delete($subject, $agentnum) if $subject;
      }
    }

    if ( $conf->exists('alert_expiration', $agentnum) ) {
      my $msgnum = $conf->exists('alerter_msgnum', $agentnum);
      my $template = FS::msg_template->by_key($msgnum) if $msgnum;
      if (!$template) {
        warn "template for alerter_msgnum $msgnum not found\n";
        next;
      }
      # this is now a set of billing events
      foreach my $days (30, 15, 5) {
        my $event = FS::part_event->new({
            'agentnum'    => $agentnum,
            'event'       => "Card expiration warning - $days days",
            'eventtable'  => 'cust_main',
            'check_freq'  => '1d',
            'action'      => 'notice',
            'disabled'    => 'Y', #initialize first
        });
        my $error = $event->insert( 'msgnum' => $msgnum );
        if ($error) {
          warn "error creating expiration alert event:\n$error\n\n";
          next;
        }
        # make it work like before:
        # only send each warning once before the card expires,
        # only warn active customers,
        # only warn customers with CARD/DCRD,
        # only warn customers who get email invoices
        my %conds = (
          'once_every'          => { 'run_delay' => '30d' },
          'cust_paydate_within' => { 'within' => $days.'d' },
          'cust_status'         => { 'status' => { 'active' => 1 } },
          'payby'               => { 'payby'  => { 'CARD' => 1,
                                                   'DCRD' => 1, }
                                   },
          'message_email'       => {},
        );
        foreach (keys %conds) {
          my $condition = FS::part_event_condition->new({
              'conditionname' => $_,
              'eventpart'     => $event->eventpart,
          });
          $error = $condition->insert( %{ $conds{$_} });
          if ( $error ) {
            warn "error creating expiration alert event:\n$error\n\n";
            next;
          }
        }
        $error = $event->initialize;
        if ( $error ) {
          warn "expiration alert event was created, but not initialized:\n$error\n\n";
        }
      } # foreach $days
      $conf->delete('alerter_msgnum', $agentnum);
      $conf->delete('alert_expiration', $agentnum);

    } # if alerter_msgnum

  }

  ###
  # Move subject and body from msg_template to template_content
  ###

  foreach my $msg_template ( qsearch('msg_template', {}) ) {
    if ( $msg_template->subject || $msg_template->body ) {
      # create new default content
      my %content;
      $content{subject} = $msg_template->subject;
      $msg_template->set('subject', '');

      # work around obscure Pg/DBD bug
      # https://rt.cpan.org/Public/Bug/Display.html?id=60200
      # (though the right fix is to upgrade DBD)
      my $body = $msg_template->body;
      if ( $body =~ /^x([0-9a-f]+)$/ ) {
        # there should be no real message templates that look like that
        warn "converting template body to TEXT\n";
        $body = pack('H*', $1);
      }
      $content{body} = $body;
      $msg_template->set('body', '');

      my $error = $msg_template->replace(%content);
      die $error if $error;
    }
  }

  ###
  # Add new-style default templates if missing
  ###
  $self->_populate_initial_data;

}

sub _populate_initial_data { #class method
  #my($class, %opts) = @_;
  #my $class = shift;

  eval "use FS::msg_template::InitialData;";
  die $@ if $@;

  my $initial_data = FS::msg_template::InitialData->_initial_data;

  foreach my $hash ( @$initial_data ) {

    next if $hash->{_conf} && $conf->config( $hash->{_conf} );

    my $msg_template = new FS::msg_template($hash);
    my $error = $msg_template->insert( @{ $hash->{_insert_args} || [] } );
    die $error if $error;

    $conf->set( $hash->{_conf}, $msg_template->msgnum ) if $hash->{_conf};
  
  }

}

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

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

