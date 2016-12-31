package FS::cust_pay_batch;
use base qw( FS::payinfo_Mixin FS::cust_main_Mixin FS::Record );

use strict;
use vars qw( $DEBUG );
use Carp qw( carp confess );
use Business::CreditCard 0.28;
use FS::Record qw(dbh qsearch qsearchs);

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;

#@encrypted_fields = ('payinfo');
sub nohistory_fields { ('payinfo'); }

=head1 NAME

FS::cust_pay_batch - Object methods for batch cards

=head1 SYNOPSIS

  use FS::cust_pay_batch;

  $record = new FS::cust_pay_batch \%hash;
  $record = new FS::cust_pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  #deprecated# $error = $record->retriable;

=head1 DESCRIPTION

An FS::cust_pay_batch object represents a credit card transaction ready to be
batched (sent to a processor).  FS::cust_pay_batch inherits from FS::Record.  
Typically called by the collect method of an FS::cust_main object.  The
following fields are currently supported:

=over 4

=item paybatchnum - primary key (automatically assigned)

=item batchnum - indentifies group in batch

=item payby - CARD/CHEK

=item payinfo

=item exp - card expiration 

=item amount 

=item invnum - invoice

=item custnum - customer 

=item payname - name on card 

=item paytype - account type ((personal|business) (checking|savings))

=item first - name 

=item last - name 

=item address1 

=item address2 

=item city 

=item state 

=item zip 

=item country 

=item status - 'Approved' or 'Declined'

=item error_message - the error returned by the gateway if any

=item failure_status - the normalized L<Business::BatchPayment> failure 
status, if any

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pay_batch'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.  If there is an error, returns the error,
otherwise returns false.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid transaction.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $conf = new FS::Conf;

  my $error = 
      $self->ut_numbern('paybatchnum')
    || $self->ut_numbern('trancode') #deprecated
    || $self->ut_money('amount')
    || $self->ut_number('invnum')
    || $self->ut_number('custnum')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || ($conf->exists('cust_main-no_city_in_address') 
        ? $self->ut_textn('city') 
        : $self->ut_text('city'))
    || $self->ut_textn('state')
  ;

  return $error if $error;

  $self->getfield('last') =~ /^([\w \,\.\-\']+)$/ or return "Illegal last name";
  $self->setfield('last',$1);

  $self->first =~ /^([\w \,\.\-\']+)$/ or return "Illegal first name";
  $self->first($1);

  $error = $self->payinfo_check();
  return $error if $error;

  if ( $self->payby eq 'CHEK' ) {
    # because '' is on the list of paytypes:
    my $paytype = $self->paytype or return "Bank account type required";
    if (grep { $_ eq $paytype} FS::cust_payby->paytypes) {
      #ok
    } else {
      return "Bank account type '$paytype' is not allowed"
    }
  } else {
    $self->set('paytype', '');
  }

  if ( $self->exp eq '' ) {
    return "Expiration date required"
      unless $self->payby =~ /^(CHEK|DCHK|WEST)$/;
    $self->exp('');
  } else {
    if ( $self->exp =~ /^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/ ) {
      $self->exp("$1-$2-$3");
    } elsif ( $self->exp =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      if ( length($2) == 4 ) {
        $self->exp("$2-$1-01");
      } elsif ( $2 > 98 ) { #should pry change to check for "this year"
        $self->exp("19$2-$1-01");
      } else {
        $self->exp("20$2-$1-01");
      }
    } else {
      return "Illegal expiration date";
    }
  }

  if ( $self->payname eq '' ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\']+)$/
      or return "Illegal billing name";
    $self->payname($1);
  }

  #we have lots of old zips in there... don't hork up batch results cause of em
  $self->zip =~ /^\s*(\w[\w\-\s]{2,8}\w)\s*$/
    or return "Illegal zip: ". $self->zip;
  $self->zip($1);

  $self->country =~ /^(\w\w)$/ or return "Illegal country: ". $self->country;
  $self->country($1);

  #$error = $self->ut_zip('zip', $self->country);
  #return $error if $error;

  #check invnum, custnum, ?

  $self->SUPER::check;
}

=item cust_main

Returns the customer (see L<FS::cust_main>) for this batched credit card
payment.

=item expmmyy

Returns the credit card expiration date in MMYY format.  If this is a 
CHEK payment, returns an empty string.

=cut

sub expmmyy {
  my $self = shift;
  if ( $self->payby eq 'CARD' ) {
    $self->get('exp') =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    return sprintf('%02u%02u', $2, ($1 % 100));
  }
  else {
    return '';
  }
}

=item pay_batch

Returns the payment batch this payment belongs to (L<FS::pay_batch).

=cut

#you know what, screw this in the new world of events.  we should be able to
#get the event defs to retry (remove once.pm condition, add every.pm) without
#mucking about with statuses of previous cust_event records.  right?
#
#=item retriable
#
#Marks the corresponding event (see L<FS::cust_bill_event>) for this batched
#credit card payment as retriable.  Useful if the corresponding financial
#institution account was declined for temporary reasons and/or a manual 
#retry is desired.
#
#Implementation details: For the named customer's invoice, changes the
#statustext of the 'done' (without statustext) event to 'retriable.'
#
#=cut

sub retriable {

  confess "deprecated method cust_pay_batch->retriable called; try removing ".
          "the once condition and adding an every condition?";

}

=item approve OPTIONS

Approve this payment.  This will replace the existing record with the 
same paybatchnum, set its status to 'Approved', and generate a payment 
record (L<FS::cust_pay>).  This should only be called from the batch 
import process.

OPTIONS may contain "gatewaynum", "processor", "auth", and "order_number".

=cut

sub approve {
  # to break up the Big Wall of Code that is import_results
  my $new = shift;
  my %opt = @_;
  my $paybatchnum = $new->paybatchnum;
  my $old = qsearchs('cust_pay_batch', { paybatchnum => $paybatchnum })
    or return "cannot approve, paybatchnum $paybatchnum not found";
  # leave these restrictions in place until TD EFT is converted over
  # to B::BP
  return "cannot approve paybatchnum $paybatchnum, already resolved ('".$old->status."')" 
    if $old->status;
  $new->status('Approved');
  my $error = $new->replace($old);
  if ( $error ) {
    return "error approving paybatchnum $paybatchnum: $error\n";
  }
  my $cust_pay = new FS::cust_pay ( {
      'custnum'   => $new->custnum,
      'payby'     => $new->payby,
      'payinfo'   => $new->payinfo || $old->payinfo,
      'paymask'   => $new->mask_payinfo,
      'paid'      => $new->paid,
      '_date'     => $new->_date,
      'usernum'   => $new->usernum,
      'batchnum'  => $new->batchnum,
      'gatewaynum'    => $opt{'gatewaynum'},
      'processor'     => $opt{'processor'},
      'auth'          => $opt{'auth'},
      'order_number'  => $opt{'order_number'} 
    } );

  $error = $cust_pay->insert;
  if ( $error ) {
    return "error inserting payment for paybatchnum $paybatchnum: $error\n";
  }
  $cust_pay->cust_main->apply_payments;
  return;
}

=item decline [ REASON [ STATUS ] ]

Decline this payment.  This will replace the existing record with the 
same paybatchnum, set its status to 'Declined', and run collection events
as appropriate.  This should only be called from the batch import process.

REASON is a string description of the decline reason, defaulting to 
'Returned payment', and will go into the "error_message" field.

STATUS is a normalized failure status defined by L<Business::BatchPayment>,
and will go into the "failure_status" field.

=cut

sub decline {
  my $new = shift;
  my $reason = shift || 'Returned payment';
  my $failure_status = shift || '';
  #my $conf = new FS::Conf;

  my $paybatchnum = $new->paybatchnum;
  my $old = qsearchs('cust_pay_batch', { paybatchnum => $paybatchnum })
    or return "cannot decline, paybatchnum $paybatchnum not found";
  if ( $old->status ) {
    # Handle the case where payments are rejected after the batch has been 
    # approved.  FS::pay_batch::import_results won't allow results to be 
    # imported to a closed batch unless batch-manual_approval is enabled, 
    # so we don't check it here.
#    if ( $conf->exists('batch-manual_approval') and
    if ( lc($old->status) eq 'approved' ) {
      # Void the payment
      my $cust_pay = qsearchs('cust_pay', { 
          custnum  => $new->custnum,
          batchnum => $new->batchnum
        });
      # these should all be migrated over, but if it's not found, look for
      # batchnum in the 'paybatch' field also
      $cust_pay ||= qsearchs('cust_pay', { 
          custnum  => $new->custnum,
          paybatch => $new->batchnum
        });
      if ( !$cust_pay ) {
        # should never happen...
        return "failed to revoke paybatchnum $paybatchnum, payment not found";
      }
      $cust_pay->void($reason);
    }
    else {
      # normal case: refuse to do anything
      return "cannot decline paybatchnum $paybatchnum, already resolved ('".$old->status."')";
    }
  } # !$old->status
  $new->status('Declined');
  $new->error_message($reason);
  $new->failure_status($failure_status);
  my $error = $new->replace($old);
  if ( $error ) {
    return "error declining paybatchnum $paybatchnum: $error\n";
  }
  my $due_cust_event = $new->cust_main->due_cust_event(
    'eventtable'  => 'cust_pay_batch',
    'objects'     => [ $new ],
  );
  if ( !ref($due_cust_event) ) {
    return $due_cust_event;
  }
  # XXX breaks transaction integrity
  foreach my $cust_event (@$due_cust_event) {
    next unless $cust_event->test_conditions;
    if ( my $error = $cust_event->do_event() ) {
      return $error;
    }
  }
  return;
}

=item request_item [ OPTIONS ]

Returns a L<Business::BatchPayment::Item> object for this batch payment
entry.  This can be submitted to a processor.

OPTIONS can be a list of key/values to append to the attributes.  The most
useful case of this is "process_date" to set a processing date based on the
date the batch is being submitted.

=cut

sub request_item {
  local $@;
  my $self = shift;

  eval "use Business::BatchPayment;";
  die "couldn't load Business::BatchPayment: $@" if $@;

  my $cust_main = $self->cust_main;
  my $location = $cust_main->bill_location;
  my $pay_batch = $self->pay_batch;

  my %payment;
  $payment{payment_type} = FS::payby->payby2bop( $pay_batch->payby );
  if ( $payment{payment_type} eq 'CC' ) {
    $payment{card_number} = $self->payinfo,
    $payment{expiration}  = $self->expmmyy,
  } elsif ( $payment{payment_type} eq 'ECHECK' ) {
    $self->payinfo =~ /(\d+)@(\d+)/; # or else what?
    $payment{account_number} = $1;
    $payment{routing_code} = $2;
    $payment{account_type} = $self->paytype;
    # XXX what if this isn't their regular payment method?
  } else {
    die "unsupported BatchPayment method: ".$pay_batch->payby;
  }

  my $recurring;
  if ( $cust_main->status =~ /^active|suspended|ordered$/ ) {
    if ( $self->payinfo_used ) {
      $recurring = 'S'; # subsequent
    } else {
      $recurring = 'F'; # first use
    }
  } else {
    $recurring = 'N'; # non-recurring
  }

  Business::BatchPayment->create(Item =>
    # required
    action      => 'payment',
    tid         => $self->paybatchnum,
    amount      => $self->amount,

    # customer info
    customer_id => $self->custnum,
    first_name  => $cust_main->first,
    last_name   => $cust_main->last,
    company     => $cust_main->company,
    address     => $location->address1,
    ( map { $_ => $location->$_ } qw(address2 city state country zip) ),
    
    invoice_number  => $self->invnum,
    recurring_billing => $recurring,
    %payment,
  );
}

=item process_unbatch_and_delete

L</unbatch_and_delete> run as a queued job, accepts I<$job> and I<$param>.

=cut

sub process_unbatch_and_delete {
  my ($job, $param) = @_;
  my $self = qsearchs('cust_pay_batch',{ 'paybatchnum' => scalar($param->{'paybatchnum'}) })
    or die 'Could not find paybatchnum ' . $param->{'paybatchnum'};
  my $error = $self->unbatch_and_delete;
  die $error if $error;
  return '';
}

=item unbatch_and_delete

May only be called on a record with an empty status and an associated
L<pay_batch> with a status of 'O' (not yet in transit.)  Deletes all associated
records from L<cust_bill_pay_batch> and then deletes this record.
If there is an error, returns the error, otherwise returns false.

=cut

sub unbatch_and_delete {
  my $self = shift;

  return 'Cannot unbatch a cust_pay_batch with status ' . $self->status
    if $self->status;

  my $pay_batch = qsearchs('pay_batch',{ 'batchnum' => $self->batchnum })
    or return 'Cannot find associated pay_batch record';

  return 'Cannot unbatch from a pay_batch with status ' . $pay_batch->status
    if $pay_batch->status ne 'O';

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # have not generated actual payments yet, so should be safe to delete
  foreach my $cust_bill_pay_batch ( 
    qsearch('cust_bill_pay_batch',{ 'paybatchnum' => $self->paybatchnum })
  ) {
    my $error = $cust_bill_pay_batch->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item cust_bill

Returns the invoice linked to this batched payment. Deprecated, will be 
removed.

=cut

sub cust_bill {
  carp "FS::cust_pay_batch->cust_bill is deprecated";
  my $self = shift;
  $self->invnum ? qsearchs('cust_bill', { invnum => $self->invnum }) : '';
}

=back

=head1 BUGS

There should probably be a configuration file with a list of allowed credit
card types.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

