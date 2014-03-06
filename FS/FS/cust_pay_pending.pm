package FS::cust_pay_pending;
use base qw( FS::payinfo_transaction_Mixin FS::cust_main_Mixin FS::Record );

use strict;
use vars qw( @encrypted_fields );
use FS::Record qw( qsearchs dbh ); #dbh for _upgrade_data
use FS::cust_pay;

@encrypted_fields = ('payinfo');
sub nohistory_fields { ('payinfo'); }

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

=item pkgnum

Desired pkgnum when using experimental package balances.

=item status

Pending transaction status, one of the following:

=over 4

=item new

Aquires basic lock on payunique

=item pending

Transaction is pending with the gateway

=item thirdparty

Customer has been sent to an off-site payment gateway to complete processing

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

=item failure_status

One of the standard failure status strings defined in 
L<Business::OnlinePayment>: "expired", "nsf", "stolen", "pickup", 
"blacklisted", "declined".  If the transaction status is not "declined", 
this will be empty.

=item gatewaynum

L<FS::payment_gateway> id.

=item paynum

Payment number (L<FS::cust_pay>) of the completed payment.

=item void_paynum

Payment number of the payment if it's been voided.

=item invnum

Invoice number (L<FS::cust_bill>) to try to apply this payment to.

=item manual

Flag for whether this is a "manual" payment (i.e. initiated through 
self-service or the back-office web interface, rather than from an event
or a payment batch).  "Manual" payments will cause the customer to be 
sent a payment receipt rather than a statement.

=item discount_term

Number of months the customer tried to prepay for.

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
    || $self->ut_textn('failure_status')
    #|| $self->ut_money('cust_balance')
    || $self->ut_hexn('session_id')
    || $self->ut_foreign_keyn('paynum', 'cust_pay', 'paynum' )
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_keyn('invnum', 'cust_bill', 'invnum')
    || $self->ut_foreign_keyn('void_paynum', 'cust_pay_void', 'paynum' )
    || $self->ut_flag('manual')
    || $self->ut_numbern('discount_term')
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

=item cust_main

Returns the associated L<FS::cust_main> record if any.  Otherwise returns false.

=cut

#these two are kind-of false laziness w/cust_main::realtime_bop
#(currently only used when resolving pending payments manually)

=item insert_cust_pay

Sets the status of this pending pament to "done" (with statustext
"captured (manual)"), and inserts a payment record (see L<FS::cust_pay>).

Currently only used when resolving pending payments manually.

=cut

sub insert_cust_pay {
  my $self = shift;

  my $cust_pay = new FS::cust_pay ( {
     'custnum'  => $self->custnum,
     'paid'     => $self->paid,
     '_date'    => $self->_date, #better than passing '' for now
     'payby'    => $self->payby,
     'payinfo'  => $self->payinfo,
     'paybatch' => $self->paybatch,
     'paydate'  => $self->paydate,
  } );

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #start a transaction, insert the cust_pay and set cust_pay_pending.status to done in a single transction

  my $error = $cust_pay->insert;#($options{'manual'} ? ( 'manual' => 1 ) : () );

  if ( $error ) {
    # gah.
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $error;
  }

  $self->status('done');
  $self->statustext('captured (manual)');
  $self->paynum($cust_pay->paynum);
  my $cpp_done_err = $self->replace;

  if ( $cpp_done_err ) {

    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $cpp_done_err;

  } else {

    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return ''; #no error

  }

}

=item approve OPTIONS

Sets the status of this pending payment to "done" and creates a completed 
payment (L<FS::cust_pay>).  This should be called when a realtime or 
third-party payment has been approved.

OPTIONS may include any of 'processor', 'payinfo', 'discount_term', 'auth',
and 'order_number' to set those fields on the completed payment, as well as 
'apply' to apply payments for this customer after inserting the new payment.

=cut

sub approve {
  my $self = shift;
  my %opt = @_;

  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $cust_pay = FS::cust_pay->new({
      'custnum'     => $self->custnum,
      'invnum'      => $self->invnum,
      'pkgnum'      => $self->pkgnum,
      'paid'        => $self->paid,
      '_date'       => '',
      'payby'       => $self->payby,
      'payinfo'     => $self->payinfo,
      'gatewaynum'  => $self->gatewaynum,
  });
  foreach my $opt_field (qw(processor payinfo auth order_number))
  {
    $cust_pay->set($opt_field, $opt{$opt_field}) if exists $opt{$opt_field};
  }

  my %insert_opt = (
    'manual'        => $self->manual,
    'discount_term' => $self->discount_term,
  );
  my $error = $cust_pay->insert( %insert_opt );
  if ( $error ) {
    # try it again without invnum or discount
    # (both of those can make payments fail to insert, and at this point
    # the payment is a done deal and MUST be recorded)
    $self->invnum('');
    my $error2 = $cust_pay->insert('manual' => $self->manual);
    if ( $error2 ) {
      # attempt to void the payment?
      # no, we'll just stop digging at this point.
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      my $e = "WARNING: payment captured but not recorded - error inserting ".
              "payment (". ($opt{processor} || $self->payby) . 
              ": $error2\n(previously tried insert with invnum#".$self->invnum.
              ": $error)\npending payment saved as paypendingnum#".
              $self->paypendingnum."\n\n";
      warn $e;
      return $e;
    }
  }
  if ( my $jobnum = $self->jobnum ) {
    my $placeholder = FS::queue->by_key($jobnum);
    my $error;
    if (!$placeholder) {
      $error = "not found";
    } else {
      $error = $placeholder->delete;
    }

    if ($error) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      my $e  = "WARNING: payment captured but could not delete job $jobnum ".
               "for paypendingnum #" . $self->paypendingnum . ": $error\n\n";
      warn $e;
      return $e;
    }
  }

  if ( $opt{'paynum_ref'} ) {
    ${ $opt{'paynum_ref'} } = $cust_pay->paynum;
  }

  $self->status('done');
  $self->statustext('captured');
  $self->paynum($cust_pay->paynum);
  my $cpp_done_err = $self->replace;

  if ( $cpp_done_err ) {

    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    my $e = "WARNING: payment captured but could not update pending status ".
            "for paypendingnum ".$self->paypendingnum.": $cpp_done_err \n\n";
    warn $e;
    return $e;

  } else {

    # commit at this stage--we don't want to roll back if applying 
    # payments fails
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;

    if ( $opt{'apply'} ) {
      my $apply_error = $self->apply_payments_and_credits;
      if ( $apply_error ) {
        warn "WARNING: error applying payment: $apply_error\n\n";
      }
    }
  }
  '';
}

=item decline [ STATUSTEXT [ STATUS ] ]

Sets the status of this pending payment to "done" (with statustext
"declined (manual)" unless otherwise specified).  The optional STATUS can be
used to set the failure_status field.

Currently only used when resolving pending payments manually.

=cut

sub decline {
  my $self = shift;
  my $statustext = shift || "declined (manual)";
  my $failure_status = shift || '';

  #could send decline email too?  doesn't seem useful in manual resolution
  # this is also used for thirdparty payment execution failures, but a decline
  # email isn't useful there either, and will just confuse people.

  $self->status('done');
  $self->statustext($statustext);
  $self->failure_status($failure_status);
  $self->replace;
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

