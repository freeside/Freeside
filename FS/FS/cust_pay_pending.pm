package FS::cust_pay_pending;

use strict;
use vars qw( @ISA  @encrypted_fields );
use FS::Record qw( qsearch qsearchs dbh ); #dbh for _upgrade_data
use FS::payby;
use FS::payinfo_Mixin;
use FS::cust_main;
use FS::cust_pay;

@ISA = qw(FS::Record FS::payinfo_Mixin);

@encrypted_fields = ('payinfo');

=head1 NAME

FS::cust_pay_pending - Object methods for cust_pay_pending records

=head1 SYNOPSIS

  use FS::cust_pay_pending;

  $record = new FS::cust_pay_pending \%hash;
  $record = new FS::cust_pay_pending { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay_pending object represents an pending payment.  It reflects 
local state through the multiple stages of processing a real-time transaction
with an external gateway.  FS::cust_pay_pending inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item paypendingnum

Primary key

=item custnum

Customer (see L<FS::cust_main>)

=item paid

Amount of this payment

=item _date

Specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby

Payment Type (See L<FS::payinfo_Mixin> for valid payby values)

=item payinfo

Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paymask

Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paydate

Expiration date

=item payunique

Unique identifer to prevent duplicate transactions.

=item status

Pending transaction status, one of the following:

=over 4

=item new

Aquires basic lock on payunique

=item pending

Transaction is pending with the gateway

=item authorized

Only used for two-stage transactions that require a separate capture step

=item captured

Transaction completed with payment gateway (sucessfully), not yet recorded in
the database

=item declined

Transaction completed with payment gateway (declined), not yet recorded in
the database

=item done

Transaction recorded in database

=back

=item statustext

Additional status information.

=cut

#=item cust_balance - 

=item paynum - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new pending payment.  To add the pending payment to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_pay_pending'; }

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

Checks all fields to make sure this is a valid pending payment.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('paypendingnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_money('paid')
    || $self->ut_numbern('_date')
    || $self->ut_textn('payunique')
    || $self->ut_text('status')
    #|| $self->ut_textn('statustext')
    || $self->ut_anything('statustext')
    #|| $self->ut_money('cust_balance')
    || $self->ut_foreign_keyn('paynum', 'cust_pay', 'paynum' )
    || $self->payinfo_check() #payby/payinfo/paymask/paydate
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  # UNIQUE index should catch this too, without race conditions, but this
  # should give a better error message the other 99.9% of the time...
  if ( length($self->payunique) ) {
    my $cust_pay_pending = qsearchs('cust_pay_pending', {
      'payunique'     => $self->payunique,
      'paypendingnum' => { op=>'!=', value=>$self->paypendingnum },
    });
    if ( $cust_pay_pending ) {
      #well, it *could* be a better error message
      return "duplicate transaction - a payment with unique identifer ".
             $self->payunique. " already exists";
    }
  }

  $self->SUPER::check;
}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data {  #class method
  my ($class, %opts) = @_;

  my $sql =
    "DELETE FROM cust_pay_pending WHERE status = 'new' AND _date < ".(time-600);

  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

