package FS::cust_pay;

use strict;
use vars qw( @ISA $conf $unsuspendauto $ignore_noapply @encrypted_fields );
use Date::Format;
use Business::CreditCard;
use Text::Template;
use FS::Misc qw(send_email);
use FS::Record qw( dbh qsearch qsearchs );
use FS::cust_main_Mixin;
use FS::payinfo_Mixin;
use FS::cust_bill;
use FS::cust_bill_pay;
use FS::cust_pay_refund;
use FS::cust_main;
use FS::cust_pay_void;

@ISA = qw(FS::Record FS::cust_main_Mixin FS::payinfo_Mixin  );

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

=item paynum - primary key (assigned automatically for new payments)

=item custnum - customer (see L<FS::cust_main>)

=item paid - Amount of this payment

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - Payment Type (See L<FS::payinfo_Mixin> for valid payby values)

=item payinfo - Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paymask - Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paybatch - text field for tracking card processing or other batch grouping

=item payunique - Optional unique identifer to prevent duplicate transactions.

=item closed - books closed flag, empty or `Y'

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

=item insert

Adds this payment to the database.

For backwards-compatibility and convenience, if the additional field invnum
is defined, an FS::cust_bill_pay record for the full amount of the payment
will be created.  In this case, custnum is optional.  An hash of optional
arguments may be passed.  Currently "manual" is supported.  If true, a
payment receipt is sent instead of a statement when 'payment_receipt_email'
configuration option is set.

=cut

sub insert {
  my ($self, %options) = @_;

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
    return "error inserting $self: $error";
  }

  if ( $self->invnum ) {
    my $cust_bill_pay = new FS::cust_bill_pay {
      'invnum' => $self->invnum,
      'paynum' => $self->paynum,
      'amount' => $self->paid,
      '_date'  => $self->_date,
    };
    $error = $cust_bill_pay->insert;
    if ( $error ) {
      if ( $ignore_noapply ) {
        warn "warning: error inserting $cust_bill_pay: $error ".
             "(ignore_noapply flag set; inserting cust_pay record anyway)\n";
      } else {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting $cust_bill_pay: $error";
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

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #my $cust_main = $self->cust_main;
  if ( $conf->exists('payment_receipt_email')
       && grep { $_ !~ /^(POST|FAX)$/ } $cust_main->invoicing_list
  ) {

    $cust_bill ||= ($cust_main->cust_bill)[-1]; #rather inefficient though?

    my $error;
    if (    ( exists($options{'manual'}) && $options{'manual'} )
         || ! $conf->exists('invoice_html_statement')
         || ! $cust_bill
       ) {

      my $receipt_template = new Text::Template (
        TYPE   => 'ARRAY',
        SOURCE => [ map "$_\n", $conf->config('payment_receipt_email') ],
      ) or do {
        warn "can't create payment receipt template: $Text::Template::ERROR";
        return '';
      };

      my @invoicing_list = grep { $_ !~ /^(POST|FAX)$/ }
                             $cust_main->invoicing_list;

      my $payby = $self->payby;
      my $payinfo = $self->payinfo;
      $payby =~ s/^BILL$/Check/ if $payinfo;
      $payinfo = $self->paymask if $payby eq 'CARD' || $payby eq 'CHEK';
      $payby =~ s/^CHEK$/Electronic check/;

      $error = send_email(
        'from'    => $conf->config('invoice_from'), #??? well as good as any
        'to'      => \@invoicing_list,
        'subject' => 'Payment receipt',
        'body'    => [ $receipt_template->fill_in( HASH => {
                       'date'    => time2str("%a %B %o, %Y", $self->_date),
                       'name'    => $cust_main->name,
                       'paynum'  => $self->paynum,
                       'paid'    => sprintf("%.2f", $self->paid),
                       'payby'   => ucfirst(lc($payby)),
                       'payinfo' => $payinfo,
                       'balance' => $cust_main->balance,
                     } ) ],
      );

    } else {

      my $queue = new FS::queue {
         'paynum' => $self->paynum,
         'job'    => 'FS::cust_bill::queueable_email',
      };
      $error = $queue->insert(
        'invnum' => $cust_bill->invnum,
        'template' => 'statement',
      );

    }

    if ( $error ) {
      warn "can't send payment receipt/statement: $error";
    }

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

  if ( $conf->config('deletepayments') ne '' ) {

    my $cust_main = $self->cust_main;

    my $error = send_email(
      'from'    => $conf->config('invoice_from'), #??? well as good as any
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

=item replace OLD_RECORD

You can, but probably shouldn't modify payments...

=cut

sub replace {
  #return "Can't modify payment!"
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

  my $error =
    $self->ut_numbern('paynum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('paid')
    || $self->ut_numbern('_date')
    || $self->ut_textn('paybatch')
    || $self->ut_textn('payunique')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->payinfo_check()
  ;
  return $error if $error;

  return "paid must be > 0 " if $self->paid <= 0;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->invnum
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  # UNIQUE index should catch this too, without race conditions, but this
  # should give a better error message the other 99.9% of the time...
  if ( length($self->payunique)
       && qsearchs('cust_pay', { 'payunique' => $self->payunique } ) ) {
    #well, it *could* be a better error message
    return "duplicate transaction".
           " - a payment with unique identifer ". $self->payunique.
           " already exists";
  }

  $self->SUPER::check;
}

=item batch_insert CUST_PAY_OBJECT, ...

Class method which inserts multiple payments.  Takes a list of FS::cust_pay
objects.  Returns a list, each element representing the status of inserting the
corresponding payment - empty.  If there is an error inserting any payment, the
entire transaction is rolled back, i.e. all payments are inserted or none are.

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

  my $errors = 0;
  
  my @errors = map {
    my $error = $_->insert( 'manual' => 1 );
    if ( $error ) { 
      $errors++;
    } else {
      $_->cust_main->apply_payments;
    }
    $error;
  } @_;

  if ( $errors ) {
    $dbh->rollback if $oldAutoCommit;
  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  }

  @errors;

}

=item cust_bill_pay

Returns all applications to invoices (see L<FS::cust_bill_pay>) for this
payment.

=cut

sub cust_bill_pay {
  my $self = shift;
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


=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=back

=head1 BUGS

Delete and replace methods.  

=head1 SEE ALSO

L<FS::cust_bill_pay>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

