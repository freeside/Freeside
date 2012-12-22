package FS::cust_credit;

use strict;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::Record );
use vars qw( $conf $unsuspendauto $me $DEBUG
             $otaker_upgrade_kludge $ignore_empty_reasonnum
           );
use List::Util qw( min );
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
$ignore_empty_reasonnum = 0;

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

  #false laziness w/ cust_pay::insert
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

=item replace [ OLD_RECORD ]

You can, but probably shouldn't modify credits... 

Replaces the OLD_RECORD with this one in the database, or, if OLD_RECORD is not
supplied, replaces this record.  If there is an error, returns the error,
otherwise returns false.

=cut

sub replace {
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
    || $self->ut_textn('addlinfo')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_keyn('eventnum', 'cust_event', 'eventnum')
  ;
  return $error if $error;

  my $method = $ignore_empty_reasonnum ? 'ut_foreign_keyn' : 'ut_foreign_key';
  $error = $self->$method('reasonnum', 'reason', 'reasonnum');
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
  local($ignore_empty_reasonnum) = 1;
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

=item credit_lineitems

Example:

  my $error = FS::cust_credit->credit_lineitems(

    #the lineitems to credit
    'billpkgnums'       => \@billpkgnums,
    'setuprecurs'       => \@setuprecurs,
    'amounts'           => \@amounts,
    'apply'             => 1, #0 leaves the credit unapplied

    #the credit
    'newreasonnum'      => scalar($cgi->param('newreasonnum')),
    'newreasonnum_type' => scalar($cgi->param('newreasonnumT')),
    map { $_ => scalar($cgi->param($_)) }
      #fields('cust_credit')  
      qw( custnum _date amount reason reasonnum addlinfo ), #pkgnum eventnum

  );

=cut

#maybe i should just be an insert with extra args instead of a class method
use FS::cust_bill_pkg;
sub credit_lineitems {
  my( $class, %arg ) = @_;
  my $curuser = $FS::CurrentUser::CurrentUser;

  #some false laziness w/misc/xmlhttp-cust_bill_pkg-calculate_taxes.html

  my $cust_main = qsearchs({
    'table'     => 'cust_main',
    'hashref'   => { 'custnum' => $arg{custnum} },
    'extra_sql' => ' AND '. $curuser->agentnums_sql,
  }) or return 'unknown customer';


  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #my @cust_bill_pkg = qsearch({
  #  'select'    => 'cust_bill_pkg.*',
  #  'table'     => 'cust_bill_pkg',
  #  'addl_from' => ' LEFT JOIN cust_bill USING (invnum)  '.
  #                 ' LEFT JOIN cust_main USING (custnum) ',
  #  'extra_sql' => ' WHERE custnum = $custnum AND billpkgnum IN ('.
  #                     join( ',', @{$arg{billpkgnums}} ). ')',
  #  'order_by'  => 'ORDER BY invnum ASC, billpkgnum ASC',
  #});

  my $error = '';
  if ($arg{reasonnum} == -1) {

    $error = 'Enter a new reason (or select an existing one)'
      unless $arg{newreasonnum} !~ /^\s*$/;
    my $reason = new FS::reason {
                   'reason'      => $arg{newreasonnum},
                   'reason_type' => $arg{newreasonnum_type},
                 };
    $error ||= $reason->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error inserting reason: $error";
    }
    $arg{reasonnum} = $reason->reasonnum;
  }

  my $cust_credit = new FS::cust_credit ( {
    map { $_ => $arg{$_} }
      #fields('cust_credit')
      qw( custnum _date amount reason reasonnum addlinfo ), #pkgnum eventnum
  } );
  $error = $cust_credit->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error inserting credit: $error";
  }

  unless ( $arg{'apply'} ) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  }

  #my $subtotal = 0;
  # keys in all of these are invoice numbers
  my %taxlisthash = ();
  my %cust_credit_bill = ();
  my %cust_bill_pkg = ();
  my %cust_credit_bill_pkg = ();
  # except here they're billpaynums
  my %unapplied_payments;
  foreach my $billpkgnum ( @{$arg{billpkgnums}} ) {
    my $setuprecur = shift @{$arg{setuprecurs}};
    my $amount = shift @{$arg{amounts}};

    my $cust_bill_pkg = qsearchs({
      'table'     => 'cust_bill_pkg',
      'hashref'   => { 'billpkgnum' => $billpkgnum },
      'addl_from' => 'LEFT JOIN cust_bill USING (invnum)',
      'extra_sql' => 'AND custnum = '. $cust_main->custnum,
    }) or die "unknown billpkgnum $billpkgnum";

    my $invnum = $cust_bill_pkg->invnum;

    if ( $setuprecur eq 'setup' ) {
      $cust_bill_pkg->setup($amount);
      $cust_bill_pkg->recur(0);
      $cust_bill_pkg->unitrecur(0);
      $cust_bill_pkg->type('');
    } else {
      $setuprecur = 'recur'; #in case its a usage classnum?
      $cust_bill_pkg->recur($amount);
      $cust_bill_pkg->setup(0);
      $cust_bill_pkg->unitsetup(0);
    }

    push @{$cust_bill_pkg{$invnum}}, $cust_bill_pkg;

    #unapply any payments applied to this line item (other credits too?)
    foreach my $cust_bill_pay_pkg ( $cust_bill_pkg->cust_bill_pay_pkg($setuprecur) ) {
      $error = $cust_bill_pay_pkg->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error unapplying payment: $error";
      }
      $unapplied_payments{$cust_bill_pay_pkg->billpaynum}
        += $cust_bill_pay_pkg->amount;
    }

    #$subtotal += $amount;
    $cust_credit_bill{$invnum} += $amount;
    push @{ $cust_credit_bill_pkg{$invnum} },
      new FS::cust_credit_bill_pkg {
        'billpkgnum' => $cust_bill_pkg->billpkgnum,
        'amount'     => sprintf('%.2f',$amount),
        'setuprecur' => $setuprecur,
        'sdate'      => $cust_bill_pkg->sdate,
        'edate'      => $cust_bill_pkg->edate,
      };

    $taxlisthash{$invnum} ||= {};
    my $part_pkg = $cust_bill_pkg->part_pkg;
    $cust_main->_handle_taxes( $part_pkg,
                               $taxlisthash{$invnum},
                               $cust_bill_pkg,
                               $cust_bill_pkg->cust_pkg,
                               $cust_bill_pkg->cust_bill->_date,
                               $cust_bill_pkg->cust_pkg->pkgpart,
                             );
  }

  ###
  # now loop through %cust_credit_bill and insert those
  ###

  # (hack to prevent cust_credit_bill_pkg insertion)
  local($FS::cust_bill_ApplicationCommon::skip_apply_to_lineitems_hack) = 1;

  foreach my $invnum ( sort { $a <=> $b } keys %cust_credit_bill ) {

    #taxes

    if ( @{ $cust_bill_pkg{$invnum} } ) {

      my $listref_or_error = 
        $cust_main->calculate_taxes(
          $cust_bill_pkg{$invnum},
          $taxlisthash{$invnum},
          $cust_bill_pkg{$invnum}->[0]->cust_bill->_date
        );

      unless ( ref( $listref_or_error ) ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error calculating taxes: $listref_or_error";
      }

      # so, loop through the taxlines, apply just that amount to the tax line
      #  item (save for later insert) & add to $

      #my @taxlines = ();
      #my $taxtotal = 0;
      foreach my $taxline ( @$listref_or_error ) {

        my $amount = $taxline->setup;

        #find equivalent tax line items on the existing invoice
        my $tax_cust_bill_pkg = qsearchs('cust_bill_pkg', {
          'invnum'   => $invnum,
          'pkgnum'   => 0, #$taxline->invnum
          'itemdesc' => $taxline->desc,
        });
        if (!$tax_cust_bill_pkg) {
          # Very debatable.  We expected the credit to include tax and 
          # the tax is not on the invoice.  Perhaps we should just bail 
          # out in this case.
          #die "missing tax line item for invnum $invnum, description ".
          #    $taxline->desc."\n";
          $cust_credit->set('amount', 
                            sprintf('%.2f', 
                              $cust_credit->get('amount') - $amount)
                            );
          my $error = $cust_credit->replace;
          die "error correcting credit for missing tax line: $error\n"
            if $error;
          next; #$taxline
        }

        # Tricky business:
        # The existing tax_Xlocation records may not have the same pkgnum as 
        # the line item we're crediting.  If there's another line item on 
        # this invoice with the same taxnum (tax table line) as this tax,
        # then they may have its pkgnum instead.  Under 2.3 there is no 
        # way to exactly find the taxes associated with a taxable item.
        # Even if the record DOES have the same pkgnum, it may include taxes 
        # from _other_ line items, and we only want to credit the amount 
        # that's due to the selected line item.
        #
        # Index the tax_Xlocation records by calculate_taxes "tax identifier".
        my %xlocation_map;
        foreach my $old_loc
          ( $tax_cust_bill_pkg->cust_bill_pkg_tax_Xlocation )
        {
          my $taxid = $old_loc->taxtype . ' ' . $old_loc->taxnum;
          warn "DUPLICATE TAX BREAKDOWN RECORD inv#$invnum $taxid\n"
            if defined($xlocation_map{$taxid});

          $xlocation_map{$taxid} = $old_loc;
        }

        #now loop over the calculated taxes
        foreach my $new_loc
          ( @{ $taxline->get('cust_bill_pkg_tax_location') },
            @{ $taxline->get('cust_bill_pkg_tax_rate_location') } )
        {
          my $taxid = $new_loc->taxtype . ' ' . $new_loc->taxnum;
          # $taxid MUST match
          my $old_loc = $xlocation_map{$taxid};
          if ( $old_loc ) {
            # then apply the amount of $new_loc to it

            #support partial credits: use $amount if smaller
            # (so just distribute to the first location?   perhaps should
            #  do so evenly...)
            my $loc_amount = min( $amount, $new_loc->amount);

            $amount -= $loc_amount;

            $cust_credit_bill{$invnum} += $loc_amount;
            push @{ $cust_credit_bill_pkg{$invnum} },
              new FS::cust_credit_bill_pkg {
                'billpkgnum'                => $tax_cust_bill_pkg->billpkgnum,
                'amount'                    => $loc_amount,
                'setuprecur'                => 'setup',
                'billpkgtaxlocationnum'     => $old_loc->billpkgtaxlocationnum,
                'billpkgtaxratelocationnum' => $old_loc->billpkgtaxratelocationnum,
              };
          } else {
            # do nothing, and apply the leftover amount nonspecifically
          }
        } #foreach my $new_loc

        if ($amount > 0) {
          #$taxtotal += $amount;
          #push @taxlines,
          #  [ $taxline->itemdesc. ' (default)', sprintf('%.2f', $amount), '', '' ];

          $cust_credit_bill{$invnum} += $amount;
          push @{ $cust_credit_bill_pkg{$invnum} },
            new FS::cust_credit_bill_pkg {
              'billpkgnum' => $tax_cust_bill_pkg->billpkgnum,
              'amount'     => $amount,
              'setuprecur' => 'setup',
            };

        } # if $amount > 0

        #unapply any payments applied to the tax
        foreach my $cust_bill_pay_pkg 
          ( $tax_cust_bill_pkg->cust_bill_pay_pkg('setup') )
        {
          $error = $cust_bill_pay_pkg->delete;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return "Error unapplying payment: $error";
          }
          $unapplied_payments{$cust_bill_pay_pkg->billpaynum}
            += $cust_bill_pay_pkg->amount;
        }
      } #foreach $taxline

    } # if @{ $cust_bill_pkg{$invnum} }

    # if we unapplied any payments from line items, also unapply that
    # amount from the invoice
    foreach my $billpaynum (keys %unapplied_payments) {
      my $cust_bill_pay = FS::cust_bill_pay->by_key($billpaynum)
        or die "broken payment application $billpaynum";
      $error = $cust_bill_pay->delete; # can't replace

      my $new_cust_bill_pay = FS::cust_bill_pay->new({
          $cust_bill_pay->hash,
          billpaynum => '',
          amount => sprintf('%.2f',
              $cust_bill_pay->get('amount') - $unapplied_payments{$billpaynum})
      });

      if ( $new_cust_bill_pay->amount > 0 ) {
        $error ||= $new_cust_bill_pay->insert;
      }
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error unapplying payment: $error";
      }
    }

    #NOW insert cust_credit_bill

    my $cust_credit_bill = new FS::cust_credit_bill {
      'crednum' => $cust_credit->crednum,
      'invnum'  => $invnum,
      'amount'  => sprintf('%.2f', $cust_credit_bill{$invnum}),
    };
    $error = $cust_credit_bill->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error applying credit of $cust_credit_bill{$invnum} ".
             " to invoice $invnum: $error";
    }

    #and then insert cust_credit_bill_pkg for each cust_bill_pkg
    foreach my $cust_credit_bill_pkg ( @{$cust_credit_bill_pkg{$invnum}} ) {
      $cust_credit_bill_pkg->creditbillnum( $cust_credit_bill->creditbillnum );
      $error = $cust_credit_bill_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error applying credit to line item: $error";
      }
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

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

