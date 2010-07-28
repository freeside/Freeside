package FS::msg_template;

use strict;
use base qw( FS::Record );
use Text::Template;
use FS::Misc qw( generate_email send_email );
use FS::Conf;
use FS::Record qw( qsearch qsearchs );

use Date::Format qw( time2str );
use HTML::Entities qw( encode_entities) ;
use vars '$DEBUG';

$DEBUG=1;

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

=item msgnum

primary key

=item msgname

Template name.

=item agentnum

Agent associated with this template.  Can be NULL for a global template.

=item mime_type

MIME type.  Defaults to text/html.

=item from_addr

Source email address.

=item subject

The message subject line, in L<Text::Template> format.

=item body

The message body, as plain text or HTML, in L<Text::Template> format.

=item disabled

disabled

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

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

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
    || $self->ut_anything('subject')
    || $self->ut_anything('body')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_textn('from_addr')
  ;
  return $error if $error;

  my $body = $self->body;
  $body =~ s/&nbsp;/ /g; # just in case these somehow get in
  $self->body($body);

  $self->mime_type('text/html') unless $self->mime_type;

  $self->SUPER::check;
}

=item prepare OPTION => VALUE

Fills in the template and returns a hash of the 'from' address, 'to' 
addresses, subject line, and body.

Options are passed as a list of name/value pairs:

=over 4

=item cust_main

Customer object (required).

=item object

Additional context object (currently, can be a cust_main object, cust_pkg
object, or cust_bill object).

=back

=cut

sub prepare {
  my( $self, %opt ) = @_;

  my $cust_main = $opt{'cust_main'};
  my $object = $opt{'object'};
  warn "preparing template '".$self->msgname."' to cust#".$cust_main->custnum."\n"
    if($DEBUG);

  my $subs = $self->substitutions;

  ###
  # create substitution table
  ###  
  my %hash;
  foreach my $obj ($cust_main, $object || ()) {
    foreach my $name (@{ $subs->{$obj->table} }) {
      if(!ref($name)) {
        # simple case
        $hash{$name} = $obj->$name();
      }
      elsif( ref($name) eq 'ARRAY' ) {
        # [ foo => sub { ... } ]
        $hash{$name->[0]} = $name->[1]->($obj);
      }
      else {
        warn "bad msg_template substitution: '$name'\n";
        #skip it?
      } 
    } 
  } 
  $_ = encode_entities($_) foreach values(%hash); # HTML escape

  ###
  # fill-in
  ###

  my $subject_tmpl = new Text::Template (
    TYPE   => 'STRING',
    SOURCE => $self->subject,
  );
  my $subject = $subject_tmpl->fill_in( HASH => \%hash );

  my $body_tmpl = new Text::Template (
    TYPE   => 'STRING',
    SOURCE => $self->body,
  );
  my $body = $body_tmpl->fill_in( HASH => \%hash );

  ###
  # and email
  ###

  my @to = $cust_main->invoicing_list_emailonly;
  #unless (@to) { #XXX do something }

  my $conf = new FS::Conf;

  (
    'from' => $self->from || 
              scalar( $conf->config('invoice_from', $cust_main->agentnum) ),
    'to'   => \@to,
    'subject'   => $subject,
    'html_body' => $body,
    #XXX auto-make a text copy w/HTML::FormatText?
    #  alas, us luddite mutt/pine users just aren't that big a deal
  );

}

=item send OPTION => VALUE

Fills in the template and sends it to the customer.  Options are as for 
'prepare'.

=cut

sub send {
  my $self = shift;
  send_email(generate_email($self->prepare(@_)));
}

# helper sub for package dates
my $ymd = sub { $_[0] ? time2str('%Y-%m-%d', $_[0]) : '' };

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
      daytime night fax

      has_ship_address
      ship_last ship_first ship_company
      ship_name ship_name_short ship_contact ship_contact_firstlast
      ship_address1 ship_address2 ship_city ship_county ship_state ship_zip
      ship_country
      ship_daytime ship_night ship_fax

      payby paymask payname paytype payip
      num_cancelled_pkgs num_ncancelled_pkgs num_pkgs
      classname categoryname
      balance
      invoicing_list_emailonly
      cust_status ucfirst_cust_status cust_statuscolor

      signupdate dundate
      ),
      [ signupdate_ymd    => sub { time2str('%Y-%m-%d', shift->signupdate) } ],
      [ dundate_ymd       => sub { time2str('%Y-%m-%d', shift->dundate) } ],
      [ paydate_my        => sub { sprintf('%02d/%04d', shift->paydate_monthyear) } ],
      [ otaker_first      => sub { shift->access_user->first } ],
      [ otaker_last       => sub { shift->access_user->last } ],
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
      [ cancel            => sub { shift->getfield('cancel') } ], # grrr...
      [ start_ymd         => sub { $ymd->(shift->getfield('start_date')) } ],
      [ setup_ymd         => sub { $ymd->(shift->getfield('setup')) } ],
      [ next_bill_ymd     => sub { $ymd->(shift->getfield('bill')) } ],
      [ last_bill_ymd     => sub { $ymd->(shift->getfield('last_bill')) } ],
      [ adjourn_ymd       => sub { $ymd->(shift->getfield('adjourn')) } ],
      [ susp_ymd          => sub { $ymd->(shift->getfield('susp')) } ],
      [ expire_ymd        => sub { $ymd->(shift->getfield('expire')) } ],
      [ cancel_ymd        => sub { $ymd->(shift->getfield('cancel')) } ],
    ],
    'cust_bill' => [qw(
      invnum
    )],
    #XXX not really thinking about cust_bill substitutions quite yet
    
    'svc_acct' => [qw(
      username
      ),
      [ password          => sub { shift->getfield('_password') } ],
    ], # for welcome messages
  };
}

sub _upgrade_data {
  my ($self, %opts) = @_;

  my @fixes = (
    [ 'alerter_msgnum',  'alerter_template',   '',               '' ],
    [ 'cancel_msgnum',   'cancelmessage',      'cancelsubject',  '' ],
    [ 'decline_msgnum',  'declinetemplate',    '',               '' ],
    [ 'impending_recur_msgnum', 'impending_recur_template', '',  '' ],
    [ 'welcome_msgnum',  'welcome_email',      'welcome_email-subject', 'welcome_email-from' ],
    [ 'warning_msgnum',  'warning_email',      'warning_email-subject', 'warning_email-from' ],
  );
 
  my $conf = new FS::Conf;
  my @agentnums = ('', map {$_->agentnum} qsearch('agent', {}));
  foreach my $agentnum (@agentnums) {
    foreach (@fixes) {
      my ($newname, $oldname, $subject, $from) = @$_;
      if ($conf->exists($oldname, $agentnum)) {
        my $new = new FS::msg_template({
           'msgname'   => $oldname,
           'agentnum'  => $agentnum,
           'from_addr' => ($from && $conf->config($from, $agentnum)) || 
                          $conf->config('invoice_from', $agentnum),
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
  }
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

