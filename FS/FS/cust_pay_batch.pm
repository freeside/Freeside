package FS::cust_pay_batch;

use strict;
use vars qw( @ISA $DEBUG );
use Carp qw( confess );
use Business::CreditCard 0.28;
use FS::Record qw(dbh qsearch qsearchs);
use FS::payinfo_Mixin;
use FS::cust_main;
use FS::cust_bill;

@ISA = qw( FS::payinfo_Mixin FS::Record );

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;

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

=item payby - CARD/CHEK/LECB/BILL/COMP

=item payinfo

=item exp - card expiration 

=item amount 

=item invnum - invoice

=item custnum - customer 

=item payname - name on card 

=item first - name 

=item last - name 

=item address1 

=item address2 

=item city 

=item state 

=item zip 

=item country 

=item status

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

  my $error = 
      $self->ut_numbern('paybatchnum')
    || $self->ut_numbern('trancode') #deprecated
    || $self->ut_money('amount')
    || $self->ut_number('invnum')
    || $self->ut_number('custnum')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('state')
  ;

  return $error if $error;

  $self->getfield('last') =~ /^([\w \,\.\-\']+)$/ or return "Illegal last name";
  $self->setfield('last',$1);

  $self->first =~ /^([\w \,\.\-\']+)$/ or return "Illegal first name";
  $self->first($1);

  $error = $self->payinfo_check();
  return $error if $error;

  if ( $self->exp eq '' ) {
    return "Expiration date required"
      unless $self->payby =~ /^(CHEK|DCHK|LECB|WEST)$/;
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

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

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

sub pay_batch {
  my $self = shift;
  FS::pay_batch->by_key($self->batchnum);
}

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

  my $self = shift;

  local $SIG{HUP} = 'IGNORE';        #Hmm
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $self->invnum } )
    or return "event $self->eventnum references nonexistant invoice $self->invnum";

  warn "cust_pay_batch->retriable working with self of " . $self->paybatchnum . " and invnum of " . $self->invnum;
  my @cust_bill_event =
    sort { $a->part_bill_event->seconds <=> $b->part_bill_event->seconds }
      grep {
        $_->part_bill_event->eventcode =~ /\$cust_bill->batch_card/
	  && $_->status eq 'done'
	  && ! $_->statustext
	}
      $cust_bill->cust_bill_event;
  # complain loudly if scalar(@cust_bill_event) > 1 ?
  my $error = $cust_bill_event[0]->retriable;
  if ($error ) {
    # gah, even with transactions.
    $dbh->commit if $oldAutoCommit; #well.
    return "error marking invoice event retriable: $error";
  }
  '';
}

=item approve PAYBATCH

Approve this payment.  This will replace the existing record with the 
same paybatchnum, set its status to 'Approved', and generate a payment 
record (L<FS::cust_pay>).  This should only be called from the batch 
import process.

=cut

sub approve {
  # to break up the Big Wall of Code that is import_results
  my $new = shift;
  my $paybatch = shift;
  my $paybatchnum = $new->paybatchnum;
  my $old = qsearchs('cust_pay_batch', { paybatchnum => $paybatchnum })
    or return "paybatchnum $paybatchnum not found";
  # leave these restrictions in place until TD EFT is converted over
  # to B::BP
  return "paybatchnum $paybatchnum already resolved ('".$old->status."')" 
    if $old->status;
  $new->status('Approved');
  my $error = $new->replace($old);
  if ( $error ) {
    return "error updating status of paybatchnum $paybatchnum: $error\n";
  }
  my $cust_pay = new FS::cust_pay ( {
      'custnum'   => $new->custnum,
      'payby'     => $new->payby,
      'paybatch'  => $paybatch,
      'payinfo'   => $new->payinfo || $old->payinfo,
      'paid'      => $new->paid,
      '_date'     => $new->_date,
      'usernum'   => $new->usernum,
      'batchnum'  => $new->batchnum,
    } );
  $error = $cust_pay->insert;
  if ( $error ) {
    return "error inserting payment for paybatchnum $paybatchnum: $error\n";
  }
  $cust_pay->cust_main->apply_payments;
  return;
}

=item decline [ REASON ]

Decline this payment.  This will replace the existing record with the 
same paybatchnum, set its status to 'Declined', and run collection events
as appropriate.  This should only be called from the batch import process.

REASON is a string description of the decline reason, defaulting to 
'Returned payment'.

=cut

sub decline {
  my $new = shift;
  my $reason = shift || 'Returned payment';
  #my $conf = new FS::Conf;

  my $paybatchnum = $new->paybatchnum;
  my $old = qsearchs('cust_pay_batch', { paybatchnum => $paybatchnum })
    or return "paybatchnum $paybatchnum not found";
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
      return "paybatchnum $paybatchnum already resolved ('".$old->status."')";
    }
  } # !$old->status
  $new->status('Declined');
  my $error = $new->replace($old);
  if ( $error ) {
    return "error updating status of paybatchnum $paybatchnum: $error\n";
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
    $payment{account_type} = $cust_main->paytype;
    # XXX what if this isn't their regular payment method?
  } else {
    die "unsupported BatchPayment method: ".$pay_batch->payby;
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
    %payment,
  );
}

=back

=head1 BUGS

There should probably be a configuration file with a list of allowed credit
card types.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

