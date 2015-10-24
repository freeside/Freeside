package FS::msg_template;
use base qw( FS::Record );

use strict;
use vars qw( $DEBUG $conf );

use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh );

use FS::cust_msg;
use FS::template_content;

use Date::Format qw(time2str);

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

=head1 NOTE

This uses a table-per-subclass ORM strategy, which is a somewhat cleaner
version of what we do elsewhere with _option tables. We could easily extract 
that functionality into a base class, or even into FS::Record itself.

=head1 DESCRIPTION

An FS::msg_template object represents a customer message template.
FS::msg_template inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item msgnum - primary key

=item msgname - Name of the template.  This will appear in the user interface;
if it needs to be localized for some users, add it to the message catalog.

=item msgclass - The L<FS::msg_template> subclass that this should belong to.
Defaults to 'email'.

=item agentnum - Agent associated with this template.  Can be NULL for a 
global template.

=item mime_type - MIME type.  Defaults to text/html.

=item from_addr - Source email address.

=item bcc_addr - Bcc all mail to this address.

=item disabled - disabled (NULL for not-disabled and selectable, 'D' for a
draft of a one-time message, 'C' for a completed one-time message, 'Y' for a
normal template disabled by user action).

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

sub extension_table { ''; } # subclasses don't HAVE to have extensions

sub _rebless {
  my $self = shift;
  my $class = 'FS::msg_template::' . $self->msgclass;
  eval "use $class;";
  bless($self, $class) unless $@;
  warn "Error loading msg_template msgclass: " . $@ if $@; #or die?

  # merge in the extension fields (but let fields in $self override them)
  # except don't ever override the extension's primary key, it's immutable
  if ( $self->msgnum and $self->extension_table ) {
    my $extension = $self->_extension;
    if ( $extension ) {
      my $ext_key = $extension->get($extension->primary_key);
      $self->{Hash} = { $extension->hash,
                        $self->hash,
                        $extension->primary_key => $ext_key
                      };
    }
  }

  $self;
}

# Returns the subclass-specific extension record for this object. For internal
# use only; everyone else is supposed to think of this as a single record.

sub _extension {
  my $self = shift;
  if ( $self->extension_table and $self->msgnum ) {
    local $FS::Record::nowarn_classload = 1;
    return qsearchs($self->extension_table, { msgnum => $self->msgnum });
  }
  return;
}

=item insert [ CONTENT ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  $self->_rebless;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error = $self->SUPER::insert;
  # calling _extension at this point makes it copy the msgnum, so links work
  if ( $self->extension_table ) {
    local $FS::Record::nowarn_classload = 1;
    my $extension = FS::Record->new($self->extension_table, { $self->hash });
    $error ||= $extension->insert;
  }

  if ( $error ) {
    dbh->rollback if $oldAutoCommit;
  } else {
    dbh->commit if $oldAutoCommit;
  }
  $error;
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error;
  my $extension = $self->_extension;
  if ( $extension ) {
    $error = $extension->delete;
  }

  $error ||= $self->SUPER::delete;

  if ( $error ) {
    dbh->rollback if $oldAutoCommit;
  } else {
    dbh->commit if $oldAutoCommit;
  }
  $error;
}

=item replace [ OLD_RECORD ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;
  my $old = shift || $new->replace_old;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error = $new->SUPER::replace($old, @_);

  my $extension = $new->_extension;
  if ( $extension ) {
    # merge changes into the extension record and replace it
    $extension->{Hash} = { $extension->hash, $new->hash };
    $error ||= $extension->replace;
  }

  if ( $error ) {
    dbh->rollback if $oldAutoCommit;
  } else {
    dbh->commit if $oldAutoCommit;
  }
  $error;
}

sub replace_check {
  my $self = shift;
  my $old = $self->replace_old;
  # don't allow changing msgclass, except null to not-null (for upgrade)
  if ( $old->msgclass ) {
    if ( !$self->msgclass ) {
      $self->set('msgclass', $old->msgclass);
    } elsif ( $old->msgclass ne $self->msgclass ) {
      return "Can't change message template class from ".$old->msgclass.
             " to ".$self->msgclass.".";
    }
  }
  '';
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
    || $self->ut_enum('disabled', [ '', 'Y', 'D', 'S' ] )
    || $self->ut_textn('from_addr')
    || $self->ut_textn('bcc_addr')
    # fine for now, but change this to some kind of dynamic check if we
    # ever have more than two msgclasses
    || $self->ut_enum('msgclass', [ qw(email http) ]),
  ;
  return $error if $error;

  $self->mime_type('text/html') unless $self->mime_type;

  $self->SUPER::check;
}

=item prepare OPTION => VALUE

Fills in the template and returns an L<FS::cust_msg> object, containing the
message to be sent.  This method must be provided by the subclass.

Options are passed as a list of name/value pairs:

=over 4

=item cust_main

Customer object

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
  die "unimplemented";
}

=item prepare_substitutions OPTION => VALUE ...

Takes the same arguments as L</prepare>, and returns a hashref of the 
substitution variables.

=cut

sub prepare_substitutions {
  my( $self, %opt ) = @_;

  my $cust_main = $opt{'cust_main'}; # or die 'cust_main required';
  my $object = $opt{'object'}; # or die 'object required';

  warn "preparing substitutions for '".$self->msgname."'\n"
    if $DEBUG;

  my $subs = $self->substitutions;

  ###
  # create substitution table
  ###  
  my %hash;
  my @objects = ();
  push @objects, $cust_main if $cust_main;
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

  return \%hash;
}

=item send OPTION => VALUE ...

Creates a message with L</prepare> (taking all the same options) and sends it.

=cut

sub send {
  my $self = shift;
  my $cust_msg = $self->prepare(@_);
  $self->send_prepared($cust_msg);
}

=item render OPTION => VALUE ...

Fills in the template and renders it to a PDF document.  Returns the 
name of the PDF file.

Options are as for 'prepare', but 'from' and 'to' are meaningless.

=cut

# XXX not sure where this ends up post-refactoring--a separate template
# class? it doesn't use the same rendering OR output machinery as ::email

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
    ),
      [ due_date2str      => sub { shift->due_date2str('short') } ],
    ],
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
    # for refund receipts
    'cust_refund' => [
      'refundnum',
      [ refund            => sub { sprintf("%.2f", shift->refund) } ],
      [ payby             => sub { FS::payby->shortname(shift->payby) } ],
      [ date              => sub { time2str("%a %B %o, %Y", shift->_date) } ],
      [ payinfo           => sub { 
          my $cust_refund = shift;
          ($cust_refund->payby eq 'CARD' || $cust_refund->payby eq 'CHEK') ?
            $cust_refund->paymask : $cust_refund->decrypt($cust_refund->payinfo)
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

Stub, returns nothing.

=cut

sub content {}

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
    [ 'welcome_msgnum',  'welcome_email',      'welcome_email-subject', 'welcome_email-from', '', 'welcome_email-mimetype' ],
    [ 'threshold_warning_msgnum',  'warning_email',      'warning_email-subject', 'warning_email-from', 'warning_email-cc', 'warning_email-mimetype' ],
  );
 
  my @agentnums = ('', map {$_->agentnum} qsearch('agent', {}));
  foreach my $agentnum (@agentnums) {
    foreach (@fixes) {
      my ($newname, $oldname, $subject, $from, $bcc, $mimetype) = @$_;
      
      if ($conf->exists($oldname, $agentnum)) {
        my $new = new FS::msg_template({
          'msgclass'  => 'email',
          'msgname'   => $oldname,
          'agentnum'  => $agentnum,
          'from_addr' => ($from && $conf->config($from, $agentnum)) || '',
          'bcc_addr'  => ($bcc && $conf->config($bcc, $agentnum)) || '',
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
        $conf->delete($bcc, $agentnum) if $bcc;
        $conf->delete($mimetype, $agentnum) if $mimetype;
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

    if ( !$msg_template->msgclass ) {
      # set default message class
      $msg_template->set('msgclass', 'email');
      my $error = $msg_template->replace;
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

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

