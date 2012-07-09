package FS::cust_pay;

use strict;
use base qw( FS::otaker_Mixin FS::payinfo_transaction_Mixin FS::cust_main_Mixin
             FS::Record );
use vars qw( $DEBUG $me $conf @encrypted_fields
             $unsuspendauto $ignore_noapply 
           );
use Date::Format;
use Business::CreditCard;
use Text::Template;
use FS::UID qw( getotaker );
use FS::Misc qw( send_email );
use FS::Record qw( dbh qsearch qsearchs );
use FS::CurrentUser;
use FS::payby;
use FS::cust_main_Mixin;
use FS::payinfo_transaction_Mixin;
use FS::cust_bill;
use FS::cust_bill_pay;
use FS::cust_pay_refund;
use FS::cust_main;
use FS::cust_pkg;
use FS::cust_pay_void;
use FS::upgrade_journal;

$DEBUG = 0;

$me = '[FS::cust_pay]';

$ignore_noapply = 0;

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $unsuspendauto = $conf->exists('unsuspendauto');
} );

@encrypted_fields = ('payinfo');

=head1 NAME

FS::cust_pay - Object methods for cust_pay objects

=head1 SYNOPSIS

  use FS::cust_pay;

  $record = new FS::cust_pay \%hash;
  $record = new FS::cust_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay object represents a payment; the transfer of money from a
customer.  FS::cust_pay inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item paynum

primary key (assigned automatically for new payments)

=item custnum

customer (see L<FS::cust_main>)

=item _date

specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item paid

Amount of this payment

=item usernum

order taker (see L<FS::access_user>)

=item payby

Payment Type (See L<FS::payinfo_Mixin> for valid values)

=item payinfo

Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paymask

Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paybatch

text field for tracking card processing or other batch grouping

=item payunique

Optional unique identifer to prevent duplicate transactions.

=item closed

books closed flag, empty or `Y'

=item pkgnum

Desired pkgnum when using experimental package balances.

=item bank

The bank where the payment was deposited.

=item depositor

The name of the depositor.

=item account

The deposit account number.

=item teller

The teller number.

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub table { 'cust_pay'; }
sub cust_linked { $_[0]->cust_main_custnum; } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_pay.paynum '. $self->paynum. ')';
}

=item insert [ OPTION => VALUE ... ]

Adds this payment to the database.

For backwards-compatibility and convenience, if the additional field invnum
is defined, an FS::cust_bill_pay record for the full amount of the payment
will be created.  In this case, custnum is optional.

If the additional field discount_term is defined then a prepayment discount
is taken for that length of time.  It is an error for the customer to owe
after this payment is made.

A hash of optional arguments may be passed.  Currently "manual" is supported.
If true, a payment receipt is sent instead of a statement when
'payment_receipt_email' configuration option is set.

=cut

sub insert {
  my($self, %options) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill;
  if ( $self->invnum ) {
    $cust_bill = qsearchs('cust_bill', { 'invnum' => $self->invnum } )
      or do {
        $dbh->rollback if $oldAutoCommit;
        return "Unknown cust_bill.invnum: ". $self->invnum;
      };
    $self->custnum($cust_bill->custnum );
  }

  my $error = $self->check;
  return $error if $error;

  my $cust_main = $self->cust_main;
  my $old_balance = $cust_main->balance;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "error inserting cust_pay: $error";
  }

  if ( my $credit_type = $conf->config('prepayment_discounts-credit_type') ) {
    if ( my $months = $self->discount_term ) {
      # XXX this should be moved out somewhere, but discount_term_values
      # doesn't fit right
      my ($cust_bill) = ($cust_main->cust_bill)[-1]; # most recent invoice
      return "can't accept prepayment for an unbilled customer" if !$cust_bill;

      # %billing_pkgs contains this customer's active monthly packages. 
      # Recurring fees for those packages will be credited and then rebilled 
      # for the full discount term.  Other packages on the last invoice 
      # (canceled, non-monthly recurring, or one-time charges) will be 
      # left as they are.
      my %billing_pkgs = map { $_->pkgnum => $_ } 
                         grep { $_->part_pkg->freq eq '1' } 
                         $cust_main->billing_pkgs;
      my $credit = 0; # sum of recurring charges from that invoice
      my $last_bill_date = 0; # the real bill date
      foreach my $item ( $cust_bill->cust_bill_pkg ) {
        next if !exists($billing_pkgs{$item->pkgnum}); # skip inactive packages
        $credit += $item->recur;
        $last_bill_date = $item->cust_pkg->last_bill 
          if defined($item->cust_pkg) 
            and $item->cust_pkg->last_bill > $last_bill_date
      }

      my $cust_credit = new FS::cust_credit {
        'custnum' => $self->custnum,
        'amount'  => sprintf('%.2f', $credit),
        'reason'  => 'customer chose to prepay for discount',
      };
      $error = $cust_credit->insert('reason_type' => $credit_type);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting prepayment credit: $error";
      }
      # don't apply it yet

      # bill for the entire term
      $_->bill($_->last_bill) foreach (values %billing_pkgs);
      $error = $cust_main->bill(
        # no recurring_only, we want unbilled packages with start dates to 
        # get billed
        'no_usage_reset' => 1,
        'time'           => $last_bill_date, # not $cust_bill->_date
        'pkg_list'       => [ values %billing_pkgs ],
        'freq_override'  => $months,
      );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_pay: $error";
      }
      $error = $cust_main->apply_payments_and_credits;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_pay: $error";
      }
      my $new_balance = $cust_main->balance;
      if ($new_balance > 0) {
        $dbh->rollback if $oldAutoCommit;
        return "balance after prepay discount attempt: $new_balance";
      }
      # user friendly: override the "apply only to this invoice" mode
      $self->invnum('');
      
    }

  }

  if ( $self->invnum ) {
    my $cust_bill_pay = new FS::cust_bill_pay {
      'invnum' => $self->invnum,
      'paynum' => $self->paynum,
      'amount' => $self->paid,
      '_date'  => $self->_date,
    };
    $error = $cust_bill_pay->insert(%options);
    if ( $error ) {
      if ( $ignore_noapply ) {
        warn "warning: error inserting cust_bill_pay: $error ".
             "(ignore_noapply flag set; inserting cust_pay record anyway)\n";
      } else {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pay: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #false laziness w/ cust_credit::insert
  if ( $unsuspendauto && $old_balance && $cust_main->balance <= 0 ) {
    my @errors = $cust_main->unsuspend;
    #return 
    # side-fx with nested transactions?  upstack rolls back?
    warn "WARNING:Errors unsuspending customer ". $cust_main->custnum. ": ".
         join(' / ', @errors)
      if @errors;
  }
  #eslaf

  #bill setup fees for voip_cdr bill_every_call packages
  #some false laziness w/search in freeside-cdrd
  my $addl_from =
    'LEFT JOIN part_pkg USING ( pkgpart ) '.
    "LEFT JOIN part_pkg_option
       ON ( cust_pkg.pkgpart = part_pkg_option.pkgpart
            AND part_pkg_option.optionname = 'bill_every_call' )";

  my $extra_sql = " AND plan = 'voip_cdr' AND optionvalue = '1' ".
                  " AND ( cust_pkg.setup IS NULL OR cust_pkg.setup = 0 ) ";

  my @cust_pkg = qsearch({
    'table'     => 'cust_pkg',
    'addl_from' => $addl_from,
    'hashref'   => { 'custnum' => $self->custnum,
                     'susp'    => '',
                     'cancel'  => '',
                   },
    'extra_sql' => $extra_sql,
  });

  if ( @cust_pkg ) {
    warn "voip_cdr bill_every_call packages found; billing customer\n";
    my $bill_error = $self->cust_main->bill_and_collect( 'fatal' => 'return' );
    if ( $bill_error ) {
      warn "WARNING: Error billing customer: $bill_error\n";
    }
  }
  #end of billing setup fees for voip_cdr bill_every_call packages

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #payment receipt
  my $trigger = $conf->config('payment_receipt-trigger', 
                              $self->cust_main->agentnum) || 'cust_pay';
  if ( $trigger eq 'cust_pay' ) {
    my $error = $self->send_receipt(
      'manual'    => $options{'manual'},
      'cust_bill' => $cust_bill,
      'cust_main' => $cust_main,
    );
    warn "can't send payment receipt/statement: $error" if $error;
  }

  '';

}

=item void [ REASON ]

Voids this payment: deletes the payment and all associated applications and
adds a record of the voided payment to the FS::cust_pay_void table.

=cut

sub void {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_pay_void = new FS::cust_pay_void ( {
    map { $_ => $self->get($_) } $self->fields
  } );
  $cust_pay_void->reason(shift) if scalar(@_);
  my $error = $cust_pay_void->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Unless the closed flag is set, deletes this payment and all associated
applications (see L<FS::cust_bill_pay> and L<FS::cust_pay_refund>).  In most
cases, you want to use the void method instead to leave a record of the
deleted payment.

=cut

# very similar to FS::cust_credit::delete
sub delete {
  my $self = shift;
  return "Can't delete closed payment" if $self->closed =~ /^Y/i;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $app ( $self->cust_bill_pay, $self->cust_pay_refund ) {
    my $error = $app->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if (    $conf->exists('deletepayments')
       && $conf->config('deletepayments') ne '' ) {

    my $cust_main = $self->cust_main;

    my $error = send_email(
      'from'    => $conf->config('invoice_from', $self->cust_main->agentnum),
                                 #invoice_from??? well as good as any
      'to'      => $conf->config('deletepayments'),
      'subject' => 'FREESIDE NOTIFICATION: Payment deleted',
      'body'    => [
        "This is an automatic message from your Freeside installation\n",
        "informing you that the following payment has been deleted:\n",
        "\n",
        'paynum: '. $self->paynum. "\n",
        'custnum: '. $self->custnum.
          " (". $cust_main->last. ", ". $cust_main->first. ")\n",
        'paid: $'. sprintf("%.2f", $self->paid). "\n",
        'date: '. time2str("%a %b %e %T %Y", $self->_date). "\n",
        'payby: '. $self->payby. "\n",
        'payinfo: '. $self->paymask. "\n",
        'paybatch: '. $self->paybatch. "\n",
      ],
    );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't send payment deletion notification: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace [ OLD_RECORD ]

You can, but probably shouldn't modify payments...

Replaces the OLD_RECORD with this one in the database, or, if OLD_RECORD is not
supplied, replaces this record.  If there is an error, returns the error,
otherwise returns false.

=cut

sub replace {
  my $self = shift;
  return "Can't modify closed payment" if $self->closed =~ /^Y/i;
  $self->SUPER::replace(@_);
}

=item check

Checks all fields to make sure this is a valid payment.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  my $error =
    $self->ut_numbern('paynum')
    || $self->ut_numbern('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('paid')
    || $self->ut_alphan('otaker')
    || $self->ut_textn('paybatch')
    || $self->ut_textn('payunique')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_textn('bank')
    || $self->ut_alphan('depositor')
    || $self->ut_numbern('account')
    || $self->ut_numbern('teller')
    || $self->payinfo_check()
  ;
  return $error if $error;

  return "paid must be > 0 " if $self->paid <= 0;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->invnum
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  return "invalid discount_term"
   if ($self->discount_term && $self->discount_term < 2);

  if ( $self->payby eq 'CASH' and $conf->exists('require_cash_deposit_info') ) {
    foreach (qw(bank depositor account teller)) {
      return "$_ required" if $self->get($_) eq '';
    }
  }

#i guess not now, with cust_pay_pending, if we actually make it here, we _do_ want to record it
#  # UNIQUE index should catch this too, without race conditions, but this
#  # should give a better error message the other 99.9% of the time...
#  if ( length($self->payunique)
#       && qsearchs('cust_pay', { 'payunique' => $self->payunique } ) ) {
#    #well, it *could* be a better error message
#    return "duplicate transaction".
#           " - a payment with unique identifer ". $self->payunique.
#           " already exists";
#  }

  $self->SUPER::check;
}

=item send_receipt HASHREF | OPTION => VALUE ...

Sends a payment receipt for this payment..

Available options:

=over 4

=item manual

Flag indicating the payment is being made manually.

=item cust_bill

Invoice (FS::cust_bill) object.  If not specified, the most recent invoice
will be assumed.

=item cust_main

Customer (FS::cust_main) object (for efficiency).

=back

=cut

sub send_receipt {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  my $cust_bill = $opt->{'cust_bill'};
  my $cust_main = $opt->{'cust_main'} || $self->cust_main;

  my $conf = new FS::Conf;

  return '' unless $conf->config_bool('payment_receipt', $cust_main->agentnum);

  my @invoicing_list = $cust_main->invoicing_list_emailonly;
  return '' unless @invoicing_list;

  $cust_bill ||= ($cust_main->cust_bill)[-1]; #rather inefficient though?

  my $error = '';

  if (    ( exists($opt->{'manual'}) && $opt->{'manual'} )
       #|| ! $conf->exists('invoice_html_statement')
       || ! $cust_bill
     )
  {
    my $msgnum = $conf->config('payment_receipt_msgnum', $cust_main->agentnum);
    if ( $msgnum ) {
      my $msg_template = FS::msg_template->by_key($msgnum);
      $error = $msg_template->send(
        'cust_main'   => $cust_main,
        'object'      => $self,
        'from_config' => 'payment_receipt_from',
      );

    } elsif ( $conf->exists('payment_receipt_email') ) {

      my $receipt_template = new Text::Template (
        TYPE   => 'ARRAY',
        SOURCE => [ map "$_\n", $conf->config('payment_receipt_email') ],
      ) or do {
        warn "can't create payment receipt template: $Text::Template::ERROR";
        return '';
      };

      my $payby = $self->payby;
      my $payinfo = $self->payinfo;
      $payby =~ s/^BILL$/Check/ if $payinfo;
      if ( $payby eq 'CARD' || $payby eq 'CHEK' ) {
        $payinfo = $self->paymask
      } else {
        $payinfo = $self->decrypt($payinfo);
      }
      $payby =~ s/^CHEK$/Electronic check/;

      my %fill_in = (
        'date'         => time2str("%a %B %o, %Y", $self->_date),
        'name'         => $cust_main->name,
        'paynum'       => $self->paynum,
        'paid'         => sprintf("%.2f", $self->paid),
        'payby'        => ucfirst(lc($payby)),
        'payinfo'      => $payinfo,
        'balance'      => $cust_main->balance,
        'company_name' => $conf->config('company_name', $cust_main->agentnum),
      );

      if ( $opt->{'cust_pkg'} ) {
        $fill_in{'pkg'} = $opt->{'cust_pkg'}->part_pkg->pkg;
        #setup date, other things?
      }

      $error = send_email(
        'from'    => $conf->config('invoice_from', $cust_main->agentnum),
                                   #invoice_from??? well as good as any
        'to'      => \@invoicing_list,
        'subject' => 'Payment receipt',
        'body'    => [ $receipt_template->fill_in( HASH => \%fill_in ) ],
      );

    } else {

      warn "payment_receipt is on, but no payment_receipt_msgnum\n";

    }

  } else { #not manual

    my $queue = new FS::queue {
       'paynum' => $self->paynum,
       'job'    => 'FS::cust_bill::queueable_email',
    };

    $error = $queue->insert(
      'invnum'      => $cust_bill->invnum,
      'template'    => 'statement',
      'notice_name' => 'Statement',
      'no_coupon'   => 1,
    );

  }
  
    warn "send_receipt: $error\n" if $error;
}

=item cust_bill_pay

Returns all applications to invoices (see L<FS::cust_bill_pay>) for this
payment.

=cut

sub cust_bill_pay {
  my $self = shift;
  map { $_ } #return $self->num_cust_bill_pay unless wantarray;
  sort {    $a->_date  <=> $b->_date
         || $a->invnum <=> $b->invnum }
    qsearch( 'cust_bill_pay', { 'paynum' => $self->paynum } )
  ;
}

=item cust_pay_refund

Returns all applications of refunds (see L<FS::cust_pay_refund>) to this
payment.

=cut

sub cust_pay_refund {
  my $self = shift;
  map { $_ } #return $self->num_cust_pay_refund unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_refund', { 'paynum' => $self->paynum } )
  ;
}


=item unapplied

Returns the amount of this payment that is still unapplied; which is
paid minus all payment applications (see L<FS::cust_bill_pay>) and refund
applications (see L<FS::cust_pay_refund>).

=cut

sub unapplied {
  my $self = shift;
  my $amount = $self->paid;
  $amount -= $_->amount foreach ( $self->cust_bill_pay );
  $amount -= $_->amount foreach ( $self->cust_pay_refund );
  sprintf("%.2f", $amount );
}

=item unrefunded

Returns the amount of this payment that has not been refuned; which is
paid minus all  refund applications (see L<FS::cust_pay_refund>).

=cut

sub unrefunded {
  my $self = shift;
  my $amount = $self->paid;
  $amount -= $_->amount foreach ( $self->cust_pay_refund );
  sprintf("%.2f", $amount );
}

=item amount

Returns the "paid" field.

=cut

sub amount {
  my $self = shift;
  $self->paid();
}

=back

=head1 CLASS METHODS

=over 4

=item batch_insert CUST_PAY_OBJECT, ...

Class method which inserts multiple payments.  Takes a list of FS::cust_pay
objects.  Returns a list, each element representing the status of inserting the
corresponding payment - empty.  If there is an error inserting any payment, the
entire transaction is rolled back, i.e. all payments are inserted or none are.

FS::cust_pay objects may have the pseudo-field 'apply_to', containing a 
reference to an array of (uninserted) FS::cust_bill_pay objects.  If so,
those objects will be inserted with the paynum of the payment, and for 
each one, an error message or an empty string will be inserted into the 
list of errors.

For example:

  my @errors = FS::cust_pay->batch_insert(@cust_pay);
  my $num_errors = scalar(grep $_, @errors);
  if ( $num_errors == 0 ) {
    #success; all payments were inserted
  } else {
    #failure; no payments were inserted.
  }

=cut

sub batch_insert {
  my $self = shift; #class method

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $num_errors = 0;
  
  my @errors;
  foreach my $cust_pay (@_) {
    my $error = $cust_pay->insert( 'manual' => 1 );
    push @errors, $error;
    $num_errors++ if $error;

    if ( ref($cust_pay->get('apply_to')) eq 'ARRAY' ) {

      foreach my $cust_bill_pay ( @{ $cust_pay->apply_to } ) {
        if ( $error ) { # insert placeholders if cust_pay wasn't inserted
          push @errors, '';
        }
        else {
          $cust_bill_pay->set('paynum', $cust_pay->paynum);
          my $apply_error = $cust_bill_pay->insert;
          push @errors, $apply_error || '';
          $num_errors++ if $apply_error;
        }
      }

    } elsif ( !$error ) { #normal case: apply payments as usual
      $cust_pay->cust_main->apply_payments;
    }

  }

  if ( $num_errors ) {
    $dbh->rollback if $oldAutoCommit;
  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  }

  @errors;

}

=item unapplied_sql

Returns an SQL fragment to retreive the unapplied amount.

=cut 

sub unapplied_sql {
  my ($class, $start, $end) = @_;
  my $bill_start   = $start ? "AND cust_bill_pay._date <= $start"   : '';
  my $bill_end     = $end   ? "AND cust_bill_pay._date > $end"     : '';
  my $refund_start = $start ? "AND cust_pay_refund._date <= $start" : '';
  my $refund_end   = $end   ? "AND cust_pay_refund._date > $end"   : '';

  "paid
        - COALESCE( 
                    ( SELECT SUM(amount) FROM cust_bill_pay
                        WHERE cust_pay.paynum = cust_bill_pay.paynum
                        $bill_start $bill_end )
                    ,0
                  )
        - COALESCE(
                    ( SELECT SUM(amount) FROM cust_pay_refund
                        WHERE cust_pay.paynum = cust_pay_refund.paynum
                        $refund_start $refund_end )
                    ,0
                  )
  ";

}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

use FS::h_cust_pay;

sub _upgrade_data {  #class method
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  ##
  # otaker/ivan upgrade
  ##

  unless ( FS::upgrade_journal->is_done('cust_pay__otaker_ivan') ) {

    #not the most efficient, but hey, it only has to run once

    my $where = "WHERE ( otaker IS NULL OR otaker = '' OR otaker = 'ivan' ) ".
                "  AND usernum IS NULL ".
                "  AND 0 < ( SELECT COUNT(*) FROM cust_main                 ".
                "              WHERE cust_main.custnum = cust_pay.custnum ) ";

    my $count_sql = "SELECT COUNT(*) FROM cust_pay $where";

    my $sth = dbh->prepare($count_sql) or die dbh->errstr;
    $sth->execute or die $sth->errstr;
    my $total = $sth->fetchrow_arrayref->[0];
    #warn "$total cust_pay records to update\n"
    #  if $DEBUG;
    local($DEBUG) = 2 if $total > 1000; #could be a while, force progress info

    my $count = 0;
    my $lastprog = 0;

    my @cust_pay = qsearch( {
        'table'     => 'cust_pay',
        'hashref'   => {},
        'extra_sql' => $where,
        'order_by'  => 'ORDER BY paynum',
    } );

    foreach my $cust_pay (@cust_pay) {

      my $h_cust_pay = $cust_pay->h_search('insert');
      if ( $h_cust_pay ) {
        next if $cust_pay->otaker eq $h_cust_pay->history_user;
        #$cust_pay->otaker($h_cust_pay->history_user);
        $cust_pay->set('otaker', $h_cust_pay->history_user);
      } else {
        $cust_pay->set('otaker', 'legacy');
      }

      delete $FS::payby::hash{'COMP'}->{cust_pay}; #quelle kludge
      my $error = $cust_pay->replace;

      if ( $error ) {
        warn " *** WARNING: Error updating order taker for payment paynum ".
             $cust_pay->paynun. ": $error\n";
        next;
      }

      $FS::payby::hash{'COMP'}->{cust_pay} = ''; #restore it

      $count++;
      if ( $DEBUG > 1 && $lastprog + 30 < time ) {
        warn "$me $count/$total (".sprintf('%.2f',100*$count/$total). '%)'."\n";
        $lastprog = time;
      }

    }

    FS::upgrade_journal->set_done('cust_pay__otaker_ivan');
  }

  ###
  # payinfo N/A upgrade
  ###

  unless ( FS::upgrade_journal->is_done('cust_pay__payinfo_na') ) {

    #XXX remove the 'N/A (tokenized)' part (or just this entire thing)

    my @na_cust_pay = qsearch( {
      'table'     => 'cust_pay',
      'hashref'   => {}, #could be encrypted# { 'payinfo' => 'N/A' },
      'extra_sql' => "WHERE ( payinfo = 'N/A' OR paymask = 'N/AA' OR paymask = 'N/A (tokenized)' ) AND payby IN ( 'CARD', 'CHEK' )",
    } );

    foreach my $na ( @na_cust_pay ) {

      next unless $na->payinfo eq 'N/A';

      my $cust_pay_pending =
        qsearchs('cust_pay_pending', { 'paynum' => $na->paynum } );
      unless ( $cust_pay_pending ) {
        warn " *** WARNING: not-yet recoverable N/A card for payment ".
             $na->paynum. " (no cust_pay_pending)\n";
        next;
      }
      $na->$_($cust_pay_pending->$_) for qw( payinfo paymask );
      my $error = $na->replace;
      if ( $error ) {
        warn " *** WARNING: Error updating payinfo for payment paynum ".
             $na->paynun. ": $error\n";
        next;
      }

    }

    FS::upgrade_journal->set_done('cust_pay__payinfo_na');
  }

  ###
  # otaker->usernum upgrade
  ###

  delete $FS::payby::hash{'COMP'}->{cust_pay}; #quelle kludge
  $class->_upgrade_otaker(%opts);
  $FS::payby::hash{'COMP'}->{cust_pay} = ''; #restore it

}

=back

=head1 SUBROUTINES

=over 4 

=item batch_import HASHREF

Inserts new payments.

=cut

sub batch_import {
  my $param = shift;

  my $fh = $param->{filehandle};
  my $agentnum = $param->{agentnum};
  my $format = $param->{'format'};
  my $paybatch = $param->{'paybatch'};

  # here is the agent virtualization
  my $extra_sql = ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @fields;
  my $payby;
  if ( $format eq 'simple' ) {
    @fields = qw( custnum agent_custid paid payinfo );
    $payby = 'BILL';
  } elsif ( $format eq 'extended' ) {
    die "unimplemented\n";
    @fields = qw( );
    $payby = 'BILL';
  } else {
    die "unknown format $format";
  }

  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;

  my $imported = 0;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  my $line;
  while ( defined($line=<$fh>) ) {

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();

    my %cust_pay = (
      payby    => $payby,
      paybatch => $paybatch,
    );

    my $cust_main;
    foreach my $field ( @fields ) {

      if ( $field eq 'agent_custid'
        && $agentnum
        && $columns[0] =~ /\S+/ )
      {

        my $agent_custid = $columns[0];
        my %hash = ( 'agent_custid' => $agent_custid,
                     'agentnum'     => $agentnum,
                   );

        if ( $cust_pay{'custnum'} !~ /^\s*$/ ) {
          $dbh->rollback if $oldAutoCommit;
          return "can't specify custnum with agent_custid $agent_custid";
        }

        $cust_main = qsearchs({
                                'table'     => 'cust_main',
                                'hashref'   => \%hash,
                                'extra_sql' => $extra_sql,
                             });

        unless ( $cust_main ) {
          $dbh->rollback if $oldAutoCommit;
          return "can't find customer with agent_custid $agent_custid";
        }

        $field = 'custnum';
        $columns[0] = $cust_main->custnum;
      }

      $cust_pay{$field} = shift @columns; 
    }

    my $cust_pay = new FS::cust_pay( \%cust_pay );
    my $error = $cust_pay->insert;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert payment for $line: $error";
    }

    if ( $format eq 'simple' ) {
      # include agentnum for less surprise?
      $cust_main = qsearchs({
                             'table'     => 'cust_main',
                             'hashref'   => { 'custnum' => $cust_pay->custnum },
                             'extra_sql' => $extra_sql,
                           })
        unless $cust_main;

      unless ( $cust_main ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't find customer to which payments apply at line: $line";
      }

      $error = $cust_main->apply_payments_and_credits;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't apply payments to customer for $line: $error";
      }

    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless $imported;

  ''; #no error

}

=back

=head1 BUGS

Delete and replace methods.  

=head1 SEE ALSO

L<FS::cust_pay_pending>, L<FS::cust_bill_pay>, L<FS::cust_bill>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

