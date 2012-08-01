package FS::cust_bill_void;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record );

use strict;
use FS::Record qw( qsearchs ); #qsearch );
use FS::cust_main;
use FS::cust_statement;
use FS::access_user;

=head1 NAME

FS::cust_bill_void - Object methods for cust_bill_void records

=head1 SYNOPSIS

  use FS::cust_bill_void;

  $record = new FS::cust_bill_void \%hash;
  $record = new FS::cust_bill_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_void object represents a voided invoice.  FS::cust_bill_void
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item invnum

primary key

=item custnum

custnum

=item _date

_date

=item charged

charged

=item invoice_terms

invoice_terms

=item previous_balance

previous_balance

=item billing_balance

billing_balance

=item closed

closed

=item statementnum

statementnum

=item agent_invid

agent_invid

=item promised_date

promised_date

=item void_date

void_date

=item reason

reason

=item void_usernum

void_usernum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new voided invoice.  To add the voided invoice to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_void'; }
sub notice_name { 'VOIDED Invoice'; }
#XXXsub template_conf { 'quotation_'; }

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

Checks all fields to make sure this is a valid voided invoice.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('invnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
    || $self->ut_textn('invoice_terms')
    || $self->ut_moneyn('previous_balance')
    || $self->ut_moneyn('billing_balance')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('statementnum', 'cust_statement', 'statementnum')
    || $self->ut_numbern('agent_invid')
    || $self->ut_numbern('promised_date')
    || $self->ut_numbern('void_date')
    || $self->ut_textn('reason')
    || $self->ut_numbern('void_usernum')
  ;
  return $error if $error;

  $self->void_date(time) unless $self->void_date;

  $self->void_usernum($FS::CurrentUser::CurrentUser->usernum)
    unless $self->void_usernum;

  $self->SUPER::check;
}

=item display_invnum

Returns the displayed invoice number for this invoice: agent_invid if
cust_bill-default_agent_invid is set and it has a value, invnum otherwise.

=cut

sub display_invnum {
  my $self = shift;
  my $conf = $self->conf;
  if ( $conf->exists('cust_bill-default_agent_invid') && $self->agent_invid ){
    return $self->agent_invid;
  } else {
    return $self->invnum;
  }
}

=item void_access_user

Returns the voiding employee object (see L<FS::access_user>).

=cut

sub void_access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->void_usernum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

