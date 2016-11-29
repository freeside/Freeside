package FS::cust_refund;

use strict;
use base qw( FS::otaker_Mixin FS::payinfo_transaction_Mixin FS::cust_main_Mixin
             FS::reason_Mixin FS::Record );
use vars qw( @encrypted_fields $me $DEBUG $ignore_empty_reasonnum );
use Business::CreditCard;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::CurrentUser;
use FS::cust_credit;
use FS::cust_credit_refund;
use FS::cust_pay_refund;
use FS::cust_main;
use FS::reason_type;
use FS::reason;

$me = '[ FS::cust_refund ]';
$DEBUG = 0;

$ignore_empty_reasonnum = 0;

@encrypted_fields = ('payinfo');
sub nohistory_fields { ('payinfo'); }

=head1 NAME

FS::cust_refund - Object method for cust_refund objects

=head1 SYNOPSIS

  use FS::cust_refund;

  $record = new FS::cust_refund \%hash;
  $record = new FS::cust_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_refund represents a refund: the transfer of money to a customer;
equivalent to a negative payment (see L<FS::cust_pay>).  FS::cust_refund
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item refundnum

primary key (assigned automatically for new refunds)

=item custnum

customer (see L<FS::cust_main>)

=item refund

Amount of the refund

=item reason

Text stating the reason for the refund ( deprecated )

=item reasonnum

Reason (see L<FS::reason>)

=item _date

specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby

Payment Type (See L<FS::payinfo_Mixin> for valid payby values)

=item payinfo

Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paycardtype

Detected credit card type, if appropriate; autodetected.

=item paymask

Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paybatch

text field for tracking card processing

=item usernum

order taker (see L<FS::access_user>

=item closed

books closed flag, empty or `Y'

=item gatewaynum, processor, auth, order_number

Same as for L<FS::cust_pay>, but specifically the result of realtime 
authorization of the refund.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new refund.  To add the refund to the database, see L<"insert">.

=cut

sub table { 'cust_refund'; }

=item insert

Adds this refund to the database.

For backwards-compatibility and convenience, if the additional field crednum is
defined, an FS::cust_credit_refund record for the full amount of the refund
will be created.  Or (this time for convenience and consistancy), if the
additional field paynum is defined, an FS::cust_pay_refund record for the full
amount of the refund will be created.  In both cases, custnum is optional.

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

  if (!$self->reasonnum) {
    my $reason_text = $self->get('reason')
      or return "reason text or existing reason required";
    my $reason_type = $options{'reason_type'}
      or return "reason type required";

    local $@;
    my $reason = FS::reason->new_or_existing(
      reason => $reason_text,
      type   => $reason_type,
      class  => 'F',
    );
    if ($@) {
      $dbh->rollback if $oldAutoCommit;
      return "failed to set refund reason: $@";
    }
    $self->set('reasonnum', $reason->reasonnum);
  }

  $self->setfield('reason', '');

  if ( $self->crednum ) {
    my $cust_credit = qsearchs('cust_credit', { 'crednum' => $self->crednum } )
      or do {
        $dbh->rollback if $oldAutoCommit;
        return "Unknown cust_credit.crednum: ". $self->crednum;
      };
    $self->custnum($cust_credit->custnum);
  } elsif ( $self->paynum ) {
    my $cust_pay = qsearchs('cust_pay', { 'paynum' => $self->paynum } )
      or do {
        $dbh->rollback if $oldAutoCommit;
        return "Unknown cust_pay.paynum: ". $self->paynum;
      };
    $self->custnum($cust_pay->custnum);
  }

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->crednum ) {
    my $cust_credit_refund = new FS::cust_credit_refund {
      'crednum'   => $self->crednum,
      'refundnum' => $self->refundnum,
      'amount'    => $self->refund,
      '_date'     => $self->_date,
    };
    $error = $cust_credit_refund->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    #$self->custnum($cust_credit_refund->cust_credit->custnum);
  } elsif ( $self->paynum ) {
    my $cust_pay_refund = new FS::cust_pay_refund {
      'paynum'    => $self->paynum,
      'refundnum' => $self->refundnum,
      'amount'    => $self->refund,
      '_date'     => $self->_date,
    };
    $error = $cust_pay_refund->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Unless the closed flag is set, deletes this refund and all associated
applications (see L<FS::cust_credit_refund> and L<FS::cust_pay_refund>).

=cut

sub delete {
  my $self = shift;
  return "Can't delete closed refund" if $self->closed =~ /^Y/i;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_credit_refund ( $self->cust_credit_refund ) {
    my $error = $cust_credit_refund->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_pay_refund ( $self->cust_pay_refund ) {
    my $error = $cust_pay_refund->delete;
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

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

You can, but probably shouldn't modify refunds... 

Replaces the OLD_RECORD with this one in the database, or, if OLD_RECORD is not
supplied, replaces this record.  If there is an error, returns the error,
otherwise returns false.

=cut

sub replace {
  my $self = shift;
  return "Can't modify closed refund" 
    if $self->closed =~ /^Y/i && !$FS::payinfo_Mixin::allow_closed_replace;
  $self->SUPER::replace(@_);
}

=item check

Checks all fields to make sure this is a valid refund.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  my $error =
    $self->ut_numbern('refundnum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('refund')
    || $self->ut_alphan('otaker')
    || $self->ut_textn('reason')
    || $self->ut_numbern('_date')
    || $self->ut_textn('paybatch')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('source_paynum', 'cust_pay', 'paynum')
  ;
  return $error if $error;

  my $method = $ignore_empty_reasonnum ? 'ut_foreign_keyn' : 'ut_foreign_key';
  $error = $self->$method('reasonnum', 'reason', 'reasonnum');
  return $error if $error;

  return "refund must be > 0 " if $self->refund <= 0;

  $self->_date(time) unless $self->_date;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->crednum 
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $error = $self->payinfo_check;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_credit_refund

Returns all applications to credits (see L<FS::cust_credit_refund>) for this
refund.

=cut

sub cust_credit_refund {
  my $self = shift;
  map { $_ } #return $self->num_cust_credit_refund unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_refund', { 'refundnum' => $self->refundnum } )
  ;
}

=item cust_pay_refund

Returns all applications to payments (see L<FS::cust_pay_refund>) for this
refund.

=cut

sub cust_pay_refund {
  my $self = shift;
  map { $_ } #return $self->num_cust_pay_refund unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_refund', { 'refundnum' => $self->refundnum } )
  ;
}

=item unapplied

Returns the amount of this refund that is still unapplied; which is
amount minus all credit applications (see L<FS::cust_credit_refund>) and
payment applications (see L<FS::cust_pay_refund>).

=cut

sub unapplied {
  my $self = shift;
  my $amount = $self->refund;
  $amount -= $_->amount foreach ( $self->cust_credit_refund );
  $amount -= $_->amount foreach ( $self->cust_pay_refund );
  sprintf("%.2f", $amount );
}

=item send_receipt HASHREF | OPTION => VALUE ...

Sends a payment receipt for this payment.

refund_receipt_msgnum must be configured.

Available options:

=over 4

=item cust_main

Customer (FS::cust_main) object (for efficiency).

=cut

=back

=cut

sub send_receipt {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  my $cust_main = $opt->{'cust_main'} || $self->cust_main;

  my $conf = new FS::Conf;
  
  my $msgnum = $conf->config('refund_receipt_msgnum', $cust_main->agentnum);
  return "No refund_receipt_msgnum configured" unless $msgnum;

  my $msg_template = qsearchs('msg_template',{ msgnum => $msgnum});
  return "Could not load template"
    unless $msg_template;

  my $cust_msg = $msg_template->prepare(
    'cust_main'     => $cust_main,
    'object'        => $self,
    'msgtype'       => 'receipt',
  );
  return 'Error preparing message' unless $cust_msg;
  my $error = $cust_msg->insert;
  return $error if $error;

  my $queue = new FS::queue {
    'job'     => 'FS::cust_msg::process_send',
    'custnum' => $cust_main->custnum,
  };
  $error = $queue->insert( $cust_msg->custmsgnum );

  return $error;
}

=back

=head1 CLASS METHODS

=over 4

=item unapplied_sql

Returns an SQL fragment to retreive the unapplied amount.

=cut 

sub unapplied_sql {
  my ($class, $start, $end) = @_;
  my $credit_start = $start ? "AND cust_credit_refund._date <= $start" : '';
  my $credit_end   = $end   ? "AND cust_credit_refund._date > $end"   : '';
  my $pay_start    = $start ? "AND cust_pay_refund._date <= $start"    : '';
  my $pay_end      = $end   ? "AND cust_pay_refund._date > $end"      : '';

  "refund
    - COALESCE( 
                ( SELECT SUM(amount) FROM cust_credit_refund
                    WHERE cust_refund.refundnum = cust_credit_refund.refundnum
                    $credit_start $credit_end )
                ,0
              )
    - COALESCE(
                ( SELECT SUM(amount) FROM cust_pay_refund
                    WHERE cust_refund.refundnum = cust_pay_refund.refundnum
                    $pay_start $pay_end )
                ,0
              )
  ";

}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
  $class->_upgrade_reasonnum(%opts);
  $class->_upgrade_otaker(%opts);

  local $ignore_empty_reasonnum = 1;
  $class->upgrade_set_cardtype;
}

=back

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit>, schema.html from the base documentation.

=cut

1;

