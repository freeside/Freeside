package FS::cust_credit;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::reason_Mixin
             FS::Record );

use strict;
use vars qw( $conf $unsuspendauto $me $DEBUG
             $otaker_upgrade_kludge $ignore_empty_reasonnum
           );
use List::Util qw( min );
use Date::Format;
use FS::UID qw( dbh );
use FS::Misc qw(send_email);
use FS::Record qw( qsearch qsearchs dbdef );
use FS::CurrentUser;
use FS::cust_pkg;
use FS::cust_refund;
use FS::cust_credit_bill;
use FS::part_pkg;
use FS::reason_type;
use FS::reason;
use FS::cust_event;
use FS::agent;
use FS::sales;
use FS::cust_credit_void;
use FS::cust_bill_pkg;
use FS::upgrade_journal;

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
sub cust_linked { $_[0]->cust_main_custnum || $_[0]->custnum } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_credit.crednum '. $self->crednum. ')';
}

=item insert [ OPTION => VALUE ... ]

Adds this credit to the database ("Posts" the credit).  If there is an error,
returns the error, otherwise returns false.

Ooptions are passed as a list of keys and values.  Available options:

=over 4

=item reason_type

L<FS::reason_type|Reason> type for newly-inserted reason

=item cust_credit_source_bill_pkg

An arrayref of
L<FS::cust_credit_source_bill_pkg|FS::cust_credit_source_bilL_pkg> objects.
They will have their crednum set and will be inserted along with this credit.

=back

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

  if (!$self->reasonnum) {
    my $reason_text = $self->get('reason')
      or return "reason text or existing reason required";
    my $reason_type = $options{'reason_type'}
      or return "reason type required";

    local $@;
    my $reason = FS::reason->new_or_existing(
      reason => $reason_text,
      type   => $reason_type,
      class  => 'R',
    );
    if ($@) {
      $dbh->rollback if $oldAutoCommit;
      return "failed to set credit reason: $@";
    }
    $self->set('reasonnum', $reason->reasonnum);
  }

  $self->setfield('reason', '');

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "error inserting $self: $error";
  }

  if ( $options{'cust_credit_source_bill_pkg'} ) {
    foreach my $ccsbr ( @{ $options{'cust_credit_source_bill_pkg'} } ) {
      $ccsbr->crednum( $self->crednum );
      $error = $ccsbr->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting $ccsbr: $error";
      }
    }
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
  my %opt = @_;

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

  if ( !$opt{void} and $conf->config('deletecredits') ne '' ) {

    my $cust_main = $self->cust_main;

    my $error = send_email(
      'from'    => $conf->invoice_from_full($self->cust_main->agentnum),
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
    || $self->ut_foreign_keyn('commission_agentnum',  'agent', 'agentnum')
    || $self->ut_foreign_keyn('commission_salesnum',  'sales', 'salesnum')
    || $self->ut_foreign_keyn('commission_pkgnum', 'cust_pkg', 'pkgnum')
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

=item void [ REASON ]

Voids this credit: deletes the credit and all associated applications and 
adds a record of the voided credit to the cust_credit_void table.

=cut

sub void {
  my $self = shift;
  my $reason = shift;

  unless (ref($reason) || !$reason) {
    $reason = FS::reason->new_or_existing(
      'class'  => 'X',
      'type'   => 'Void credit',
      'reason' => $reason
    );
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_credit_void = new FS::cust_credit_void ( {
      map { $_ => $self->get($_) } $self->fields
    } );
  $cust_credit_void->set('void_reasonnum', $reason->reasonnum) if $reason;
  my $error = $cust_credit_void->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $error = $self->delete(void => 1); # suppress deletecredits warning
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

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

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data {  # class method
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  $class->_upgrade_reasonnum(%opts);

  if (defined dbdef->table($class->table)->column('reason')) {

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

  if ( !FS::upgrade_journal->is_done('cust_credit__tax_link')
      and !$conf->config('tax_data_vendor') ) {
    # RT#25458: fix credit line item applications that should refer to a 
    # specific tax allocation
    my @cust_credit_bill_pkg = qsearch({
        table     => 'cust_credit_bill_pkg',
        select    => 'cust_credit_bill_pkg.*',
        addl_from => ' LEFT JOIN cust_bill_pkg USING (billpkgnum)',
        extra_sql =>
          'WHERE cust_credit_bill_pkg.billpkgtaxlocationnum IS NULL '.
          'AND cust_bill_pkg.pkgnum = 0', # is a tax
    });
    my %tax_items;
    my %credits;
    foreach (@cust_credit_bill_pkg) {
      my $billpkgnum = $_->billpkgnum;
      $tax_items{$billpkgnum} ||= FS::cust_bill_pkg->by_key($billpkgnum);
      $credits{$billpkgnum} ||= [];
      push @{ $credits{$billpkgnum} }, $_;
    }
    TAX_ITEM: foreach my $tax_item (values %tax_items) {
      my $billpkgnum = $tax_item->billpkgnum;
      # get all pkg/location/taxrate allocations of this tax line item
      my @allocations = sort {$b->amount <=> $a->amount}
                        qsearch('cust_bill_pkg_tax_location', {
                            billpkgnum => $billpkgnum
                        });
      # and these are all credit applications to it
      my @credits = sort {$b->amount <=> $a->amount}
                    @{ $credits{$billpkgnum} };
      my $c = shift @credits;
      my $a = shift @allocations; # we will NOT modify these
      while ($c and $a) {
        if ( abs($c->amount - $a->amount) < 0.005 ) {
          # by far the most common case: the tax line item is for a single
          # tax, so we just fill in the billpkgtaxlocationnum
          $c->set('billpkgtaxlocationnum', $a->billpkgtaxlocationnum);
          my $error = $c->replace;
          if ($error) {
            warn "error fixing credit application to tax item #$billpkgnum:\n$error\n";
            next TAX_ITEM;
          }
          $c = shift @credits;
          $a = shift @allocations;
        } elsif ( $c->amount > $a->amount ) {
          # fairly common: the tax line contains tax for multiple packages
          # (or multiple taxes) but the credit isn't divided up
          my $new_link = FS::cust_credit_bill_pkg->new({
              creditbillnum         => $c->creditbillnum,
              billpkgnum            => $c->billpkgnum,
              billpkgtaxlocationnum => $a->billpkgtaxlocationnum,
              amount                => $a->amount,
              setuprecur            => 'setup',
          });
          my $error = $new_link->insert;
          if ($error) {
            warn "error fixing credit application to tax item #$billpkgnum:\n$error\n";
            next TAX_ITEM;
          }
          $c->set(amount => sprintf('%.2f', $c->amount - $a->amount));
          $a = shift @allocations;
        } elsif ( $c->amount < 0.005 ) {
          # also fairly common; we can delete these with no harm
          my $error = $c->delete;
          warn "error removing zero-amount credit application (probably harmless):\n$error\n" if $error;
          $c = shift @credits;
        } elsif ( $c->amount < $a->amount ) {
          # should never happen, but if it does, handle it gracefully
          $c->set('billpkgtaxlocationnum', $a->billpkgtaxlocationnum);
          my $error = $c->replace;
          if ($error) {
            warn "error fixing credit application to tax item #$billpkgnum:\n$error\n";
            next TAX_ITEM;
          }
          $a->set(amount => $a->amount - $c->amount);
          $c = shift @credits;
        }
      } # while $c and $a
      if ( $c ) {
        if ( $c->amount < 0.005 ) {
          my $error = $c->delete;
          warn "error removing zero-amount credit application (probably harmless):\n$error\n" if $error;
        } elsif ( $c->modified ) {
          # then we've allocated part of it, so reduce the nonspecific 
          # application by that much
          my $error = $c->replace;
          warn "error fixing credit application to tax item #$billpkgnum:\n$error\n" if $error;
        }
        # else there are probably no allocations, i.e. this is a pre-3.x 
        # record that was never migrated over, so leave it alone
      } # if $c
    } # foreach $tax_item
    FS::upgrade_journal->set_done('cust_credit__tax_link');
  }
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

=item calculate_tax_adjustment PARAMS

Calculate the amount of tax that needs to be credited as part of a lineitem
credit.

PARAMS must include:

- billpkgnums: arrayref identifying the line items to credit
- setuprecurs: arrayref of 'setup' or 'recur', indicating which part of
  the lineitem charge is being credited
- amounts: arrayref of the amounts to credit on each line item
- custnum: the customer all of these invoices belong to, for error checking

Returns a hash containing:
- subtotal: the total non-tax amount to be credited (the sum of the 'amounts')
- taxtotal: the total tax amount to be credited
- taxlines: an arrayref of hashrefs for each tax line to be credited, each with:
  - table: "cust_bill_pkg_tax_location" or "cust_bill_pkg_tax_rate_location"
  - num: the key within that table
  - credit: the credit amount to apply to that line

=cut

sub calculate_tax_adjustment {
  my ($class, %arg) = @_;

  my $error;
  my @taxlines;
  my $subtotal = 0;
  my $taxtotal = 0;

  my (%cust_bill_pkg, %cust_bill);

  for (my $i = 0; ; $i++) {
    my $billpkgnum = $arg{billpkgnums}[$i]
      or last;
    my $setuprecur = $arg{setuprecurs}[$i];
    my $amount = $arg{amounts}[$i];
    next if $amount == 0;
    $subtotal += $amount;
    my $cust_bill_pkg = $cust_bill_pkg{$billpkgnum}
                    ||= FS::cust_bill_pkg->by_key($billpkgnum)
      or die "lineitem #$billpkgnum not found\n";

    my $invnum = $cust_bill_pkg->invnum;
    $cust_bill{ $invnum } ||= FS::cust_bill->by_key($invnum);
    $cust_bill{ $invnum}->custnum == $arg{custnum}
      or die "lineitem #$billpkgnum not found\n";

    # calculate credit ratio.
    # (First deduct any existing credits applied to this line item, to avoid
    # rounding errors.)
    my $charged = $cust_bill_pkg->get($setuprecur);
    my $previously_credited =
      $cust_bill_pkg->credited( '', '', setuprecur => $setuprecur) || 0;

    $charged -= $previously_credited;
    if ($charged < $amount) {
      $error = "invoice #$invnum: tried to credit $amount, but only $charged was charged";
      last;
    }
    my $ratio = $amount / $charged;

    # gather taxes that apply to the selected item
    foreach my $table (
      qw(cust_bill_pkg_tax_location cust_bill_pkg_tax_rate_location)
    ) {
      foreach my $tax_link (
        qsearch($table, { taxable_billpkgnum => $billpkgnum })
      ) {
        my $tax_amount = $tax_link->amount;
        # deduct existing credits applied to the tax, for the same reason as
        # above
        foreach ($tax_link->cust_credit_bill_pkg) {
          $tax_amount -= $_->amount;
        }
        my $tax_credit = sprintf('%.2f', $tax_amount * $ratio);
        my $pkey = $tax_link->get($tax_link->primary_key);
        push @taxlines, {
          table   => $table,
          num     => $pkey,
          credit  => $tax_credit,
        };
        $taxtotal += $tax_credit;

      } #foreach cust_bill_pkg_tax_(rate_)?location
    }
  } # foreach $billpkgnum

  return (
    subtotal => sprintf('%.2f', $subtotal),
    taxtotal => sprintf('%.2f', $taxtotal),
    taxlines => \@taxlines,
  );
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
    map { $_ => scalar($cgi->param($_)) }
      #fields('cust_credit')  
      qw( custnum _date amount reasonnum addlinfo ), #pkgnum eventnum

  );

=cut

#maybe i should just be an insert with extra args instead of a class method
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

  my $cust_credit = new FS::cust_credit ( {
    map { $_ => $arg{$_} }
      #fields('cust_credit')
      qw( custnum _date amount reasonnum addlinfo ), #pkgnum eventnum
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
  my %cust_credit_bill = ();
  my %cust_bill_pkg = ();
  my %cust_credit_bill_pkg = ();
  my %unapplied_payments = (); #invoice numbers, and then billpaynums

  # determine the tax adjustments
  my %tax_adjust = $class->calculate_tax_adjustment(%arg);

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

    push @{$cust_bill_pkg{$invnum}}, $cust_bill_pkg;

    $cust_credit_bill{$invnum} += $amount;
    push @{ $cust_credit_bill_pkg{$invnum} },
      new FS::cust_credit_bill_pkg {
        'billpkgnum' => $billpkgnum,
        'amount'     => sprintf('%.2f',$amount),
        'setuprecur' => $setuprecur,
        'sdate'      => $cust_bill_pkg->sdate,
        'edate'      => $cust_bill_pkg->edate,
      };
    # unapply payments (but not other credits) from this line item
    foreach my $cust_bill_pay_pkg (
      $cust_bill_pkg->cust_bill_pay_pkg($setuprecur)
    ) {
      $error = $cust_bill_pay_pkg->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error unapplying payment: $error";
      }
      $unapplied_payments{$invnum}{$cust_bill_pay_pkg->billpaynum}
        += $cust_bill_pay_pkg->amount;
    }
  }

  # do the same for taxes
  foreach my $tax_credit ( @{ $tax_adjust{taxlines} } ) {
    my $table = $tax_credit->{table};
    my $tax_link = "FS::$table"->by_key( $tax_credit->{num} )
      or die "tried to credit $table #$tax_credit->{num} but it doesn't exist";

    my $billpkgnum = $tax_link->billpkgnum;
    my $cust_bill_pkg = qsearchs({
      'table'     => 'cust_bill_pkg',
      'hashref'   => { 'billpkgnum' => $billpkgnum },
      'addl_from' => 'LEFT JOIN cust_bill USING (invnum)',
      'extra_sql' => 'AND custnum = '. $cust_main->custnum,
    }) or die "unknown billpkgnum $billpkgnum";
    
    my $invnum = $cust_bill_pkg->invnum;
    push @{$cust_bill_pkg{$invnum}}, $cust_bill_pkg;

    my $amount = $tax_credit->{credit};
    $cust_credit_bill{$invnum} += $amount;

    # create a credit application record to the tax line item, earmarked
    # to the specific cust_bill_pkg_Xlocation
    push @{ $cust_credit_bill_pkg{$invnum} },
      new FS::cust_credit_bill_pkg {
        'billpkgnum' => $billpkgnum,
        'amount'     => sprintf('%.2f', $amount),
        'setuprecur' => 'setup',
        $tax_link->primary_key, $tax_credit->{num}
      };
    # unapply any payments from the tax
    foreach my $cust_bill_pay_pkg (
      $cust_bill_pkg->cust_bill_pay_pkg('setup')
    ) {
      $error = $cust_bill_pay_pkg->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error unapplying payment: $error";
      }
      $unapplied_payments{$invnum}{$cust_bill_pay_pkg->billpaynum}
        += $cust_bill_pay_pkg->amount;
    }
  }

  ###
  # now loop through %cust_credit_bill and insert those
  ###

  # (hack to prevent cust_credit_bill_pkg insertion)
  local($FS::cust_bill_ApplicationCommon::skip_apply_to_lineitems_hack) = 1;

  foreach my $invnum ( sort { $a <=> $b } keys %cust_credit_bill ) {

    # if we unapplied any payments from line items, also unapply that 
    # amount from the invoice
    foreach my $billpaynum (keys %{$unapplied_payments{$invnum}}) {
      my $cust_bill_pay = FS::cust_bill_pay->by_key($billpaynum)
        or die "broken payment application $billpaynum";
      my @subapps = $cust_bill_pay->lineitem_applications;
      $error = $cust_bill_pay->delete; # can't replace

      my $new_cust_bill_pay = FS::cust_bill_pay->new({
          $cust_bill_pay->hash,
          billpaynum => '',
          amount => sprintf('%.2f', 
              $cust_bill_pay->amount 
              - $unapplied_payments{$invnum}{$billpaynum}),
      });

      if ( $new_cust_bill_pay->amount > 0 ) {
        $error ||= $new_cust_bill_pay->insert;
        # Also reapply it to everything it was applied to before.
        # Note that we've already deleted cust_bill_pay_pkg records for the
        # items we're crediting, so they aren't on this list.
        foreach my $cust_bill_pay_pkg (@subapps) {
          $cust_bill_pay_pkg->billpaypkgnum('');
          $cust_bill_pay_pkg->billpaynum($new_cust_bill_pay->billpaynum);
          $error ||= $cust_bill_pay_pkg->insert;
        }
      }
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error unapplying payment: $error";
      }
    }
    #insert cust_credit_bill

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

=head1 SUBROUTINES

=over 4

=item process_batch_import

=cut

use List::Util qw( min );
use FS::cust_bill;
use FS::cust_credit_bill;
sub process_batch_import {
  my $job = shift;

  my $opt = { 'table'   => 'cust_credit',
              'params'  => [ '_date', 'credbatch' ],
              'formats' => { 'simple' =>
                               [ 'custnum', 'amount', 'reasonnum', 'invnum' ],
                           },
              'default_csv' => 1,
              'postinsert_callback' => sub {
                my $cust_credit = shift; #my ($cust_credit, $param ) = @_;

                if ( $cust_credit->invnum ) {

                  my $cust_bill = qsearchs('cust_bill', { invnum=>$cust_credit->invnum } );
                  my $amount = min( $cust_credit->credited, $cust_bill->owed );
    
                  my $cust_credit_bill = new FS::cust_credit_bill ( {
                    'crednum' => $cust_credit->crednum,
                    'invnum'  => $cust_bill->invnum,
                    'amount'  => $amount,
                  } );
                  my $error = $cust_credit_bill->insert;
                  return '' unless $error;

                }

                #apply_payments_and_credits ?
                $cust_credit->cust_main->apply_credits;

                return '';

              },
            };

  FS::Record::process_batch_import( $job, $opt, @_ );

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

