package FS::msg_template;

use strict;
use base qw( FS::Record );
use Text::Template;
use FS::Misc qw( generate_email send_email );
use FS::Conf;
use FS::Record qw( qsearch qsearchs );

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

msgname

=item agentnum

agentnum

=item mime_type

mime_type

=item body

body

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
    || $self->ut_anything('body')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->mime_type('text/html') unless $self->mime_type;

  $self->SUPER::check;
}

=item send OPTION => VALUE, ...

Fills in the template and emails it to the customer.

Options are passed as a list of name/value pairs:

=over 4

=item cust_main

Customer object (required).

=item object

Additional context object (currently, can be a cust_main object, cust_pkg
object, or cust_bill object).

=back

=cut

sub send {
  my( $self, %opt ) = @_;

  my $cust_main = $opt{'cust_main'};
  my $object = $opt{'object'};

  ###
  # fill-in
  ###

  my $subs = $self->substitutions;
  
  #XXX html escape this stuff
  my %hash = map { $_ => $cust_main->$_() } @{ $subs->{'cust_main'} };
  unless ( ! $object || $object->table eq 'cust_main' ) {
    %hash = ( %hash, map { $_ => $object->$_() } @{ $subs->{$object->table} } );
  }

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

  send_email(
    generate_email(
       #XXX override from in event?
      'from' => scalar( $conf->config('invoice_from', $cust_main->agentnum) ),
      'to'   => \@to,
      'subject'   => $subject,
      'html_body' => $body,
      #XXX auto-make a text copy w/HTML::FormatText?
      #  alas, us luddite mutt/pine users just aren't that big a deal
    )
  );

}

#return contexts and fill-in values
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
    )],
    #XXX make these pretty: signupdate dundate paydate_monthyear usernum
    # next_bill_date

    'cust_pkg'  => [qw(
    )],
    #XXX these are going to take more pretty-ing up

    'cust_bill' => [qw(
      invnum
    )],
    #XXX not really thinking about cust_bill substitutions quite yet

  };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

