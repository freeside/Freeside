package FS::cust_credit;

use strict;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::Record );
use vars qw( $conf $unsuspendauto $me $DEBUG $otaker_upgrade_kludge );
use Date::Format;
use FS::UID qw( dbh getotaker );
use FS::Misc qw(send_email);
use FS::Record qw( qsearch qsearchs dbdef );
use FS::CurrentUser;
use FS::cust_main;
use FS::cust_pkg;
use FS::cust_refund;
use FS::cust_credit_bill;
use FS::part_pkg;
use FS::reason_type;
use FS::reason;
use FS::cust_event;

$me = '[ FS::cust_credit ]';
$DEBUG = 0;

$otaker_upgrade_kludge = 0;

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_credit'} = sub { 

  $conf = new FS::Conf;
  $unsuspendauto = $conf->exists('unsuspendauto');

};

our %reasontype_map = ( 'referral_credit_type' => 'Referral Credit',
                        'cancel_credit_type'   => 'Cancellation Credit',
                        'signup_credit_type'   => 'Self-Service Credit',
                      );

=head1 NAME

FS::cust_credit - Object methods for cust_credit records

=head1 SYNOPSIS

  use FS::cust_credit;

  $record = new FS::cust_credit \%hash;
  $record = new FS::cust_credit { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit object represents a credit; the equivalent of a negative
B<cust_bill> record (see L<FS::cust_bill>).  FS::cust_credit inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item crednum

Primary key (assigned automatically for new credits)

=item custnum

Customer (see L<FS::cust_main>)

=item amount

Amount of the credit

=item _date

Specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item usernum

Order taker (see L<FS::access_user>)

=item reason

Text ( deprecated )

=item reasonnum

Reason (see L<FS::reason>)

=item addlinfo

Text

=item closed

Books closed flag, empty or `Y'

=item pkgnum

Desired pkgnum when using experimental package balances.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new credit.  To add the credit to the database, see L<"insert">.

=cut

sub table { 'cust_credit'; }
sub cust_linked { $_[0]->cust_main_custnum; } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_credit.crednum '. $self->crednum. ')';
}

=item insert

Adds this credit to the database ("Posts" the credit).  If there is an error,
returns the error, otherwise returns false.

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

  my $cust_main = qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
  my $old_balance = $cust_main->balance;

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

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "error inserting $self: $error";
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

  '';

}

=item delete

Unless the closed flag is set, deletes this credit and all associated
applications (see L<FS::cust_credit_bill>).  In most cases, you want to use
the void method instead to leave a record of the deleted credit.

=cut

# very similar to FS::cust_pay::delete
sub delete {
  my $self = shift;
  return "Can't delete closed credit" if $self->closed =~ /^Y/i;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_credit_bill ( $self->cust_credit_bill ) {
    my $error = $cust_credit_bill->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_credit_refund ( $self->cust_credit_refund ) {
    my $error = $cust_credit_refund->delete;
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

  if ( $conf->config('deletecredits') ne '' ) {

    my $cust_main = $self->cust_main;

    my $error = send_email(
      'from'    => $conf->config('invoice_from', $self->cust_main->agentnum),
                                 #invoice_from??? well as good as any
      'to'      => $conf->config('deletecredits'),
      'subject' => 'FREESIDE NOTIFICATION: Credit deleted',
      'body'    => [
        "This is an automatic message from your Freeside installation\n",
        "informing you that the following credit has been deleted:\n",
        "\n",
        'crednum: '. $self->crednum. "\n",
        'custnum: '. $self->custnum.
          " (". $cust_main->last. ", ". $cust_main->first. ")\n",
        'amount: $'. sprintf("%.2f", $self->amount). "\n",
        'date: '. time2str("%a %b %e %T %Y", $self->_date). "\n",
        'reason: '. $self->reason. "\n",
      ],
    );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't send credit deletion notification: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

You can, but probably shouldn't modify credits... 

=cut

sub replace {
  #return "Can't modify credit!"
  my $self = shift;
  return "Can't modify closed credit" if $self->closed =~ /^Y/i;
  $self->SUPER::replace(@_);
}

=item check

Checks all fields to make sure this is a valid credit.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  my $error =
    $self->ut_numbern('crednum')
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
    || $self->ut_alphan('otaker')
    || $self->ut_textn('reason')
    || $self->ut_foreign_key('reasonnum', 'reason', 'reasonnum')
    || $self->ut_textn('addlinfo')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_keyn('eventnum', 'cust_event', 'eventnum')
  ;
  return $error if $error;

  return "amount must be > 0 " if $self->amount <= 0;

  return "amount must be greater or equal to amount applied"
    if $self->unapplied < 0 && ! $otaker_upgrade_kludge;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->SUPER::check;
}

=item cust_credit_refund

Returns all refund applications (see L<FS::cust_credit_refund>) for this credit.

=cut

sub cust_credit_refund {
  my $self = shift;
  map { $_ } #return $self->num_cust_credit_refund unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_refund', { 'crednum' => $self->crednum } )
  ;
}

=item cust_credit_bill

Returns all application to invoices (see L<FS::cust_credit_bill>) for this
credit.

=cut

sub cust_credit_bill {
  my $self = shift;
  map { $_ } #return $self->num_cust_credit_bill unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_bill', { 'crednum' => $self->crednum } )
  ;
}

=item unapplied

Returns the amount of this credit that is still unapplied/outstanding; 
amount minus all refund applications (see L<FS::cust_credit_refund>) and
applications to invoices (see L<FS::cust_credit_bill>).

=cut

sub unapplied {
  my $self = shift;
  my $amount = $self->amount;
  $amount -= $_->amount foreach ( $self->cust_credit_refund );
  $amount -= $_->amount foreach ( $self->cust_credit_bill );
  sprintf( "%.2f", $amount );
}

=item credited

Deprecated name for the unapplied method.

=cut

sub credited {
  my $self = shift;
  #carp "cust_credit->credited deprecated; use ->unapplied";
  $self->unapplied(@_);
}

=item cust_main

Returns the customer (see L<FS::cust_main>) for this credit.

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
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
    my $extra_sql = " AND reason_type.class='R'"; 

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

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data {  # class method
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  if (defined dbdef->table($class->table)->column('reason')) {

    warn "$me Checking for unmigrated reasons\n" if $DEBUG;

    my @cust_credits = qsearch({ 'table'     => $class->table,
                                 'hashref'   => {},
                                 'extra_sql' => 'WHERE reason IS NOT NULL',
                              });

    if (scalar(grep { $_->getfield('reason') =~ /\S/ } @cust_credits)) {
      warn "$me Found unmigrated reasons\n" if $DEBUG;
      my $hashref = { 'class' => 'R', 'type' => 'Legacy' };
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

      foreach my $cust_credit ( @cust_credits ) {
        my $reason = $cust_credit->getfield('reason');
        warn "Contemplating reason $reason\n" if $DEBUG > 1;
        if ($reason =~ /\S/) {
          $cust_credit->reason($reason, 'reason_type' => $reason_type->typenum)
            or die "can't insert legacy reason $reason into database\n";
        }else{
          $cust_credit->reasonnum($noreason->reasonnum);
        }

        $cust_credit->setfield('reason', '');
        my $error = $cust_credit->replace;

        warn "*** WARNING: error replacing reason in $class ".
             $cust_credit->crednum. ": $error ***\n"
          if $error;
      }
    }

    warn "$me Ensuring existance of auto reasons\n" if $DEBUG;

    foreach ( keys %reasontype_map ) {
      unless ($conf->config($_)) {       # hmmmm
#       warn "$me Found $_ reason type lacking\n" if $DEBUG;
#       my $hashref = { 'class' => 'R', 'type' => $reasontype_map{$_} };
        my $hashref = { 'class' => 'R', 'type' => 'Legacy' };
        my $reason_type = qsearchs( 'reason_type', $hashref );
        unless ($reason_type) {
          $reason_type  = new FS::reason_type( $hashref );
          my $error   = $reason_type->insert();
          die "$class had error inserting FS::reason_type into database: $error\n"
            if $error;
        }
        $conf->set($_, $reason_type->typenum);
      }
    }

    warn "$me Ensuring commission packages have a reason type\n" if $DEBUG;

    my $hashref = { 'class' => 'R', 'type' => 'Legacy' };
    my $reason_type = qsearchs( 'reason_type', $hashref );
    unless ($reason_type) {
      $reason_type  = new FS::reason_type( $hashref );
      my $error   = $reason_type->insert();
      die "$class had error inserting FS::reason_type into database: $error\n"
        if $error;
    }

    my @plans = qw( flat_comission flat_comission_cust flat_comission_pkg );
    foreach my $plan ( @plans ) {
      foreach my $pkg ( qsearch('part_pkg', { 'plan' => $plan } ) ) {
        unless ($pkg->option('reason_type', 1) ) { 
          my $plandata = $pkg->plandata.
                        "reason_type=". $reason_type->typenum. "\n";
          $pkg->plandata($plandata);
          my $error =
            $pkg->replace( undef,
                           'pkg_svc' => { map { $_->svcpart => $_->quantity }
                                          $pkg->pkg_svc
                                        },
                           'primary_svc' => $pkg->svcpart,
                         );
            die "failed setting reason_type option: $error"
              if $error;
        }
      }
    }
  }

  local($otaker_upgrade_kludge) = 1;
  $class->_upgrade_otaker(%opts);

}

=back

=head1 CLASS METHODS

=over 4

=item unapplied_sql

Returns an SQL fragment to retreive the unapplied amount.

=cut

sub unapplied_sql {
  my ($class, $start, $end) = @_;

  my $bill_start   = $start ? "AND cust_credit_bill._date <= $start"   : '';
  my $bill_end     = $end   ? "AND cust_credit_bill._date > $end"     : '';
  my $refund_start = $start ? "AND cust_credit_refund._date <= $start" : '';
  my $refund_end   = $end   ? "AND cust_credit_refund._date > $end"   : '';

  "amount
        - COALESCE(
                    ( SELECT SUM(amount) FROM cust_credit_refund
                        WHERE cust_credit.crednum = cust_credit_refund.crednum
                        $refund_start $refund_end )
                    ,0
                  )
        - COALESCE(
                    ( SELECT SUM(amount) FROM cust_credit_bill
                        WHERE cust_credit.crednum = cust_credit_bill.crednum
                        $bill_start $bill_end )
                    ,0
                  )
  ";

}

=item credited_sql

Deprecated name for the unapplied_sql method.

=cut

sub credited_sql {
  #my $class = shift;

  #carp "cust_credit->credited_sql deprecated; use ->unapplied_sql";

  #$class->unapplied_sql(@_);
  unapplied_sql();
}

=back

=head1 BUGS

The delete method.  The replace method.

B<credited> and B<credited_sql> are now called B<unapplied> and
B<unapplied_sql>.  The old method names should start to give warnings.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit_refund>, L<FS::cust_refund>,
L<FS::cust_credit_bill> L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

