package FS::cust_refund;

use strict;
use base qw( FS::otaker_Mixin FS::payinfo_transaction_Mixin FS::cust_main_Mixin
             FS::Record );
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

  unless ($self->reasonnum) {
    my $result = $self->reason( $self->getfield('reason'),
                                exists($options{ 'reason_type' })
                                  ? ('reason_type' => $options{ 'reason_type' })
                                  : (),
                              );
    unless($result) {
      $dbh->rollback if $oldAutoCommit;
      return "failed to set reason for $me"; #: ". $dbh->errstr;
    }
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
  return "Can't modify closed refund" if $self->closed =~ /^Y/i;
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

=item reason

Returns the text of the associated reason (see L<FS::reason>) for this credit.

=cut

sub reason {
  my ($self, $value, %options) = @_;
  my $dbh = dbh;
  my $reason;
  my $typenum = $options{'reason_type'};

  my $oldAutoCommit = $FS::UID::AutoCommit;  # this should already be in
  local $FS::UID::AutoCommit = 0;            # a transaction if it matters

  if ( defined( $value ) ) {
    my $hashref = { 'reason' => $value };
    $hashref->{'reason_type'} = $typenum if $typenum;
    my $addl_from = "LEFT JOIN reason_type ON ( reason_type = typenum ) ";
    my $extra_sql = " AND reason_type.class='F'";

    $reason = qsearchs( { 'table'     => 'reason',
                          'hashref'   => $hashref,
                          'addl_from' => $addl_from,
                          'extra_sql' => $extra_sql,
                       } );

    if (!$reason && $typenum) {
      $reason = new FS::reason( { 'reason_type' => $typenum,
                                  'reason' => $value,
                                  'disabled' => 'Y',
                              } );
      my $error = $reason->insert;
      if ( $error ) {
        warn "error inserting reason: $error\n";
        $reason = undef;
      }
    }

    $self->reasonnum($reason ? $reason->reasonnum : '') ;
    warn "$me reason used in set mode with non-existant reason -- clearing"
      unless $reason;
  }
  $reason = qsearchs( 'reason', { 'reasonnum' => $self->reasonnum } );

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ( $reason ? $reason->reason : '' ).
  ( $self->addlinfo ? ' '.$self->addlinfo : '' );
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  if (defined dbdef->table($class->table)->column('reason')) {

    warn "$me Checking for unmigrated reasons\n" if $DEBUG;

    my @cust_refunds = qsearch({ 'table'     => $class->table,
                                 'hashref'   => {},
                                 'extra_sql' => 'WHERE reason IS NOT NULL',
                              });

    if (scalar(grep { $_->getfield('reason') =~ /\S/ } @cust_refunds)) {
      warn "$me Found unmigrated reasons\n" if $DEBUG;
      my $hashref = { 'class' => 'F', 'type' => 'Legacy' };
      my $reason_type = qsearchs( 'reason_type', $hashref );
      unless ($reason_type) {
        $reason_type  = new FS::reason_type( $hashref );
        my $error   = $reason_type->insert();
        die "$class had error inserting FS::reason_type into database: $error\n"
          if $error;
      }

      $hashref = { 'reason_type' => $reason_type->typenum,
                   'reason' => '(none)'
                 };
      my $noreason = qsearchs( 'reason', $hashref );
      unless ($noreason) {
        $hashref->{'disabled'} = 'Y';
        $noreason = new FS::reason( $hashref );
        my $error  = $noreason->insert();
        die "can't insert legacy reason '(none)' into database: $error\n"
          if $error;
      }

      foreach my $cust_refund ( @cust_refunds ) {
        my $reason = $cust_refund->getfield('reason');
        warn "Contemplating reason $reason\n" if $DEBUG > 1;
        if ($reason =~ /\S/) {
          $cust_refund->reason($reason, 'reason_type' => $reason_type->typenum)
            or die "can't insert legacy reason $reason into database\n";
        }else{
          $cust_refund->reasonnum($noreason->reasonnum);
        }

        $cust_refund->setfield('reason', '');
        my $error = $cust_refund->replace;

        warn "*** WARNING: error replacing reason in $class ".
             $cust_refund->refundnum. ": $error ***\n"
          if $error;
      }
    }
  }
  $class->_upgrade_otaker(%opts);
}

=back

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit>, schema.html from the base documentation.

=cut

1;

