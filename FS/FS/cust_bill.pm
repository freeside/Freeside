package FS::cust_bill;
use base qw( FS::cust_bill::Search FS::Template_Mixin
             FS::cust_main_Mixin FS::Record
           );

use strict;
use vars qw( $DEBUG $me );
             # but NOT $conf
use Carp;
use Fcntl qw(:flock); #for spool_csv
use Cwd;
use List::Util qw(min max sum);
use Date::Format;
use DateTime;
use File::Temp 0.14;
use HTML::Entities;
use Storable qw( freeze thaw );
use GD::Barcode;
use FS::UID qw( datasrc );
use FS::Misc qw( send_fax do_print );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_statement;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_detail;
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_pkg;
use FS::cust_credit_bill;
use FS::pay_batch;
use FS::cust_event;
use FS::part_pkg;
use FS::cust_bill_pay;
use FS::payby;
use FS::bill_batch;
use FS::cust_bill_batch;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::discount_plan;
use FS::cust_bill_void;
use FS::reason;
use FS::reason_type;
use FS::L10N;

$DEBUG = 0;
$me = '[FS::cust_bill]';

=head1 NAME

FS::cust_bill - Object methods for cust_bill records

=head1 SYNOPSIS

  use FS::cust_bill;

  $record = new FS::cust_bill \%hash;
  $record = new FS::cust_bill { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ( $total_previous_balance, @previous_cust_bill ) = $record->previous;

  @cust_bill_pkg_objects = $cust_bill->cust_bill_pkg;

  ( $total_previous_credits, @previous_cust_credit ) = $record->cust_credit;

  @cust_pay_objects = $cust_bill->cust_pay;

  $tax_amount = $record->tax;

  @lines = $cust_bill->print_text;
  @lines = $cust_bill->print_text('time' => $time);

=head1 DESCRIPTION

An FS::cust_bill object represents an invoice; a declaration that a customer
owes you money.  The specific charges are itemized as B<cust_bill_pkg> records
(see L<FS::cust_bill_pkg>).  FS::cust_bill inherits from FS::Record.  The
following fields are currently supported:

Regular fields

=over 4

=item invnum - primary key (assigned automatically for new invoices)

=item custnum - customer (see L<FS::cust_main>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item charged - amount of this invoice

=item invoice_terms - optional terms override for this specific invoice

=back

Deprecated fields

=over 4

=item billing_balance - the customer's balance immediately before generating
this invoice.  DEPRECATED.  Use the L<FS::cust_main/balance_date> method
to determine the customer's balance at a specific time.

=item previous_balance - the customer's balance immediately after generating
the invoice before this one.  DEPRECATED.

=item printed - formerly used to track the number of times an invoice had
been printed; no longer used.

=back

Specific use cases

=over 4

=item closed - books closed flag, empty or `Y'

=item statementnum - invoice aggregation (see L<FS::cust_statement>)

=item agent_invid - legacy invoice number

=item promised_date - customer promised payment date, for collection

=item pending - invoice is still being generated, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice.  To add the invoice to the database, see L<"insert">.
Invoices are normally created by calling the bill method of a customer object
(see L<FS::cust_main>).

=cut

sub table { 'cust_bill'; }
sub template_conf { 'invoice_'; }

sub has_sections {
  my $self = shift;
  my $agentnum = $self->cust_main->agentnum;
  my $tc = $self->template_conf;

  $self->conf->exists($tc.'sections', $agentnum) ||
  $self->conf->exists($tc.'sections_by_location', $agentnum);
}

# should be the ONLY occurrence of "Invoice" in invoice rendering code.
# (except email_subject and invnum_date_pretty)
sub notice_name {
  my $self = shift;
  $self->conf->config('notice_name') || 'Invoice'
}

sub cust_linked { $_[0]->cust_main_custnum || $_[0]->custnum }
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_bill.invnum '. $self->invnum. ')';
}

=item insert

Adds this invoice to the database ("Posts" the invoice).  If there is an error,
returns the error, otherwise returns false.

=cut

sub insert {
  my $self = shift;
  warn "$me insert called\n" if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->get('cust_bill_pkg') ) {
    foreach my $cust_bill_pkg ( @{$self->get('cust_bill_pkg')} ) {
      $cust_bill_pkg->invnum($self->invnum);
      my $error = $cust_bill_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't create invoice line item: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item void [ REASON ]

Voids this invoice: deletes the invoice and adds a record of the voided invoice
to the FS::cust_bill_void table (and related tables starting from
FS::cust_bill_pkg_void).

=cut

sub void {
  my $self = shift;
  my $reason = scalar(@_) ? shift : '';

  unless (ref($reason) || !$reason) {
    $reason = FS::reason->new_or_existing(
      'class'  => 'I',
      'type'   => 'Invoice void',
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

  my $cust_bill_void = new FS::cust_bill_void ( {
    map { $_ => $self->get($_) } $self->fields
  } );
  $cust_bill_void->reasonnum($reason->reasonnum) if $reason;
  my $error = $cust_bill_void->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
    my $error = $cust_bill_pkg->void($reason);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $error = $self->_delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

# removed docs entirely and renamed method to _delete to further indicate it is
# internal-only and discourage use
#
# =item delete
#
# DO NOT USE THIS METHOD.  Instead, apply a credit against the invoice, or use
# the B<void> method.
#
# This is only for internal use by V<void>, which is what you should be using.
#
# DO NOT USE THIS METHOD.  Whatever reason you think you have is almost certainly
# wrong.  Use B<void>, that's what it is for.  Really.  This means you.
#
# =cut

sub _delete {
  my $self = shift;
  return "Can't delete closed invoice" if $self->closed =~ /^Y/i;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $table (qw(
    cust_credit_bill
    cust_bill_pay_batch
    cust_bill_pay
    cust_bill_batch
    cust_bill_pkg
  )) {
    #cust_event # problematic
    #cust_pay_batch # unnecessary

    foreach my $linked ( $self->$table() ) {
      my $error = $linked->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
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

=item replace [ OLD_RECORD ]

You can, but probably shouldn't modify invoices...

Replaces the OLD_RECORD with this one in the database, or, if OLD_RECORD is not
supplied, replaces this record.  If there is an error, returns the error,
otherwise returns false.

=cut

#replace can be inherited from Record.pm

# replace_check is now the preferred way to #implement replace data checks
# (so $object->replace() works without an argument)

sub replace_check {
  my( $new, $old ) = ( shift, shift );
  return "Can't modify closed invoice" if $old->closed =~ /^Y/i;
  #return "Can't change _date!" unless $old->_date eq $new->_date;
  return "Can't change _date" unless $old->_date == $new->_date;
  return "Can't change charged" unless $old->charged == $new->charged
                                    || $old->pending eq 'Y'
                                    || $old->charged == 0
				    || $new->{'Hash'}{'cc_surcharge_replace_hack'};

  '';
}


=item add_cc_surcharge

Giant hack

=cut

sub add_cc_surcharge {
    my ($self, $pkgnum, $amount) = (shift, shift, shift);

    my $error;
    my $cust_bill_pkg = new FS::cust_bill_pkg({
				    'invnum' => $self->invnum,
				    'pkgnum' => $pkgnum,
				    'setup' => $amount,
			});
    $error = $cust_bill_pkg->insert;
    return $error if $error;

    $self->{'Hash'}{'cc_surcharge_replace_hack'} = 1;
    $self->charged($self->charged+$amount);
    $error = $self->replace;
    return $error if $error;

    $self->apply_payments_and_credits;
}


=item check

Checks all fields to make sure this is a valid invoice.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('invnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
    || $self->ut_numbern('printed')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('statementnum', 'cust_statement', 'statementnum' )
    || $self->ut_numbern('agent_invid') #varchar?
    || $self->ut_flag('pending')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->printed(0) if $self->printed eq '';

  $self->SUPER::check;
}

=item display_invnum

Returns the displayed invoice number for this invoice: agent_invid if
cust_bill-default_agent_invid is set and it has a value, invnum otherwise.

=cut

sub display_invnum {
  my $self = shift;
  if ( $self->agent_invid
         && FS::Conf->new->exists('cust_bill-default_agent_invid') ) {
    return $self->agent_invid;
  } else {
    return $self->invnum;
  }
}

=item previous_bill

Returns the customer's last invoice before this one.

=cut

sub previous_bill {
  my $self = shift;
  if ( !$self->get('previous_bill') ) {
    $self->set('previous_bill', qsearchs({
          'table'     => 'cust_bill',
          'hashref'   => { 'custnum'  => $self->custnum,
                           '_date'    => { op=>'<', value=>$self->_date } },
          'order_by'  => 'ORDER BY _date DESC LIMIT 1',
    }) );
  }
  $self->get('previous_bill');
}

=item following_bill

Returns the customer's invoice that follows this one

=cut

sub following_bill {
  my $self = shift;
  if (!$self->get('following_bill')) {
    $self->set('following_bill', qsearchs({
      table   => 'cust_bill',
      hashref => {
        custnum => $self->custnum,
        invnum  => { op => '>', value => $self->invnum },
      },
      order_by => 'ORDER BY invnum ASC LIMIT 1',
    }));
  }
  $self->get('following_bill');
}

=item previous

Returns a list consisting of the total previous balance for this customer,
followed by the previous outstanding invoices (as FS::cust_bill objects also).

=cut

sub previous {
  my $self = shift;
  # simple memoize; we use this a lot
  if (!$self->get('previous')) {
    my $total = 0;
    my @cust_bill = sort { $a->_date <=> $b->_date }
      grep { $_->owed != 0 }
        qsearch( 'cust_bill', { 'custnum' => $self->custnum,
                                #'_date'   => { op=>'<', value=>$self->_date },
                                'invnum'   => { op=>'<', value=>$self->invnum },
                              } )
    ;
    foreach ( @cust_bill ) { $total += $_->owed; }
    $self->set('previous', [$total, @cust_bill]);
  }
  return @{ $self->get('previous') };
}

=item enable_previous

Whether to show the 'Previous Charges' section when printing this invoice.
The negation of the 'disable_previous_balance' config setting.

=cut

sub enable_previous {
  my $self = shift;
  my $agentnum = $self->cust_main->agentnum;
  !$self->conf->exists('disable_previous_balance', $agentnum);
}

=item cust_bill_pkg

Returns the line items (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearch(
    { 'table'    => 'cust_bill_pkg',
      'hashref'  => { 'invnum' => $self->invnum },
      'order_by' => 'ORDER BY billpkgnum', #important?  otherwise we could use
                                           # the AUTLOADED FK search.  or should
                                           # that default to ORDER by the pkey?
    }
  );
}

=item cust_bill_pkg_pkgnum PKGNUM

Returns the line items (see L<FS::cust_bill_pkg>) for this invoice and
specified pkgnum.

=cut

sub cust_bill_pkg_pkgnum {
  my( $self, $pkgnum ) = @_;
  qsearch(
    { 'table'    => 'cust_bill_pkg',
      'hashref'  => { 'invnum' => $self->invnum,
                      'pkgnum' => $pkgnum,
                    },
      'order_by' => 'ORDER BY billpkgnum',
    }
  );
}

=item cust_pkg

Returns the packages (see L<FS::cust_pkg>) corresponding to the line items for
this invoice.

=cut

sub cust_pkg {
  my $self = shift;
  my @cust_pkg = map { $_->pkgnum > 0 ? $_->cust_pkg : () }
                     $self->cust_bill_pkg;
  my %saw = ();
  grep { ! $saw{$_->pkgnum}++ } @cust_pkg;
}

=item no_auto

Returns true if any of the packages (or their definitions) corresponding to the
line items for this invoice have the no_auto flag set.

=cut

sub no_auto {
  my $self = shift;
  grep { $_->no_auto || $_->part_pkg->no_auto } $self->cust_pkg;
}

=item open_cust_bill_pkg

Returns the open line items for this invoice.

Note that cust_bill_pkg with both setup and recur fees are returned as two
separate line items, each with only one fee.

=cut

# modeled after cust_main::open_cust_bill
sub open_cust_bill_pkg {
  my $self = shift;

  # grep { $_->owed > 0 } $self->cust_bill_pkg

  my %other = ( 'recur' => 'setup',
                'setup' => 'recur', );
  my @open = ();
  foreach my $field ( qw( recur setup )) {
    push @open, map  { $_->set( $other{$field}, 0 ); $_; }
                grep { $_->owed($field) > 0 }
                $self->cust_bill_pkg;
  }

  @open;
}

=item cust_event

Returns the new-style customer billing events (see L<FS::cust_event>) for this invoice.

=cut

#false laziness w/cust_pkg.pm
sub cust_event {
  my $self = shift;
  qsearch({
    'table'     => 'cust_event',
    'addl_from' => 'JOIN part_event USING ( eventpart )',
    'hashref'   => { 'tablenum' => $self->invnum },
    'extra_sql' => " AND eventtable = 'cust_bill' ",
  });
}

=item num_cust_event

Returns the number of new-style customer billing events (see L<FS::cust_event>) for this invoice.

=cut

#false laziness w/cust_pkg.pm
sub num_cust_event {
  my $self = shift;
  my $sql =
    "SELECT COUNT(*) FROM cust_event JOIN part_event USING ( eventpart ) ".
    "  WHERE tablenum = ? AND eventtable = 'cust_bill'";
  my $sth = dbh->prepare($sql) or die  dbh->errstr. " preparing $sql";
  $sth->execute($self->invnum) or die $sth->errstr. " executing $sql";
  $sth->fetchrow_arrayref->[0];
}

=item cust_main

Returns the customer (see L<FS::cust_main>) for this invoice.

=item suspend

Suspends all unsuspended packages (see L<FS::cust_pkg>) for this invoice

Returns a list: an empty list on success or a list of errors.

=cut

sub suspend {
  my $self = shift;

  grep { $_->suspend(@_) }
  grep {! $_->getfield('cancel') }
  $self->cust_pkg;

}

=item cust_suspend_if_balance_over AMOUNT

Suspends the customer associated with this invoice if the total amount owed on
this invoice and all older invoices is greater than the specified amount.

Returns a list: an empty list on success or a list of errors.

=cut

sub cust_suspend_if_balance_over {
  my( $self, $amount ) = ( shift, shift );
  my $cust_main = $self->cust_main;
  if ( $cust_main->total_owed_date($self->_date) < $amount ) {
    return ();
  } else {
    $cust_main->suspend(@_);
  }
}

=item cancel

Cancel the packages on this invoice. Largely similar to the cust_main version, but does not bother yet with banned payment options

=cut

sub cancel {
  my( $self, %opt ) = @_;

  warn "$me cancel called on cust_bill ". $self->invnum . " with options ".
       join(', ', map { "$_: $opt{$_}" } keys %opt ). "\n"
    if $DEBUG;

  return ( 'Access denied' )
    unless $FS::CurrentUser::CurrentUser->access_right('Cancel customer');

  my @pkgs = $self->cust_pkg;

  if ( !$opt{nobill} && $self->conf->exists('bill_usage_on_cancel') ) {
    $opt{nobill} = 1;
    my $error = $self->cust_main->bill( pkg_list => [ @pkgs ], cancel => 1 );
    warn "Error billing during cancel, custnum ". $self->custnum. ": $error"
      if $error;
  }

  grep { $_ }
    map { $_->cancel(%opt) }
      grep { ! $_->getfield('cancel') }
        @pkgs;
}

=item cust_bill_pay

Returns all payment applications (see L<FS::cust_bill_pay>) for this invoice.

=cut

sub cust_bill_pay {
  my $self = shift;
  map { $_ } #return $self->num_cust_bill_pay unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_bill_pay', { 'invnum' => $self->invnum } );
}

=item cust_credited

=item cust_credit_bill

Returns all applied credits (see L<FS::cust_credit_bill>) for this invoice.

=cut

sub cust_credited {
  my $self = shift;
  map { $_ } #return $self->num_cust_credit_bill unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_bill', { 'invnum' => $self->invnum } )
  ;
}

sub cust_credit_bill {
  shift->cust_credited(@_);
}

#=item cust_bill_pay_pkgnum PKGNUM
#
#Returns all payment applications (see L<FS::cust_bill_pay>) for this invoice
#with matching pkgnum.
#
#=cut
#
#sub cust_bill_pay_pkgnum {
#  my( $self, $pkgnum ) = @_;
#  map { $_ } #return $self->num_cust_bill_pay_pkgnum($pkgnum) unless wantarray;
#  sort { $a->_date <=> $b->_date }
#    qsearch( 'cust_bill_pay', { 'invnum' => $self->invnum,
#                                'pkgnum' => $pkgnum,
#                              }
#           );
#}

=item cust_bill_pay_pkg PKGNUM

Returns all payment applications (see L<FS::cust_bill_pay>) for this invoice
applied against the matching pkgnum.

=cut

sub cust_bill_pay_pkg {
  my( $self, $pkgnum ) = @_;

  qsearch({
    'select'    => 'cust_bill_pay_pkg.*',
    'table'     => 'cust_bill_pay_pkg',
    'addl_from' => ' LEFT JOIN cust_bill_pay USING ( billpaynum ) '.
                   ' LEFT JOIN cust_bill_pkg USING ( billpkgnum ) ',
    'extra_sql' => ' WHERE cust_bill_pkg.invnum = '. $self->invnum.
                   "   AND cust_bill_pkg.pkgnum = $pkgnum",
  });

}

#=item cust_credited_pkgnum PKGNUM
#
#=item cust_credit_bill_pkgnum PKGNUM
#
#Returns all applied credits (see L<FS::cust_credit_bill>) for this invoice
#with matching pkgnum.
#
#=cut
#
#sub cust_credited_pkgnum {
#  my( $self, $pkgnum ) = @_;
#  map { $_ } #return $self->num_cust_credit_bill_pkgnum($pkgnum) unless wantarray;
#  sort { $a->_date <=> $b->_date }
#    qsearch( 'cust_credit_bill', { 'invnum' => $self->invnum,
#                                   'pkgnum' => $pkgnum,
#                                 }
#           );
#}
#
#sub cust_credit_bill_pkgnum {
#  shift->cust_credited_pkgnum(@_);
#}

=item cust_credit_bill_pkg PKGNUM

Returns all credit applications (see L<FS::cust_credit_bill>) for this invoice
applied against the matching pkgnum.

=cut

sub cust_credit_bill_pkg {
  my( $self, $pkgnum ) = @_;

  qsearch({
    'select'    => 'cust_credit_bill_pkg.*',
    'table'     => 'cust_credit_bill_pkg',
    'addl_from' => ' LEFT JOIN cust_credit_bill USING ( creditbillnum ) '.
                   ' LEFT JOIN cust_bill_pkg    USING ( billpkgnum    ) ',
    'extra_sql' => ' WHERE cust_bill_pkg.invnum = '. $self->invnum.
                   "   AND cust_bill_pkg.pkgnum = $pkgnum",
  });

}

=item cust_bill_batch

Returns all invoice batch records (L<FS::cust_bill_batch>) for this invoice.

=cut

sub cust_bill_batch {
  my $self = shift;
  qsearch('cust_bill_batch', { 'invnum' => $self->invnum });
}

=item discount_plans

Returns all discount plans (L<FS::discount_plan>) for this invoice, as a
hash keyed by term length.

=cut

sub discount_plans {
  my $self = shift;
  FS::discount_plan->all($self);
}

=item tax

Returns the tax amount (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub tax {
  my $self = shift;
  my $total = 0;
  my @taxlines = qsearch( 'cust_bill_pkg', { 'invnum' => $self->invnum ,
                                             'pkgnum' => 0 } );
  foreach (@taxlines) { $total += $_->setup; }
  $total;
}

=item owed

Returns the amount owed (still outstanding) on this invoice, which is charged
minus all payment applications (see L<FS::cust_bill_pay>) and credit
applications (see L<FS::cust_credit_bill>).

=cut

sub owed {
  my $self = shift;
  my $balance = $self->charged;
  $balance -= $_->amount foreach ( $self->cust_bill_pay );
  $balance -= $_->amount foreach ( $self->cust_credited );
  $balance = sprintf( "%.2f", $balance);
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

=item owed_on_invoice

Returns the amount to be displayed as the "Balance Due" on this
invoice.  Amount returned depends on conf flags for invoicing

See L<FS::cust_bill::owed> for the true amount currently owed

=cut

sub owed_on_invoice {
  my $self = shift;

  #return $self->owed()
  #  unless $self->conf->exists('previous_balance-payments_since')

  # Add charges from this invoice
  my $owed = $self->charged();

  # Add carried balances from previous invoices
  #   If previous items aren't to be displayed on the invoice,
  #   _items_previous() is aware of this and responds appropriately.
  $owed += $_->{amount} for $self->_items_previous();

  # Subtract payments and credits displayed on this invoice
  $owed -= $_->{amount} for $self->_items_payments(), $self->_items_credits();

  return $owed;
}

sub owed_pkgnum {
  my( $self, $pkgnum ) = @_;

  #my $balance = $self->charged;
  my $balance = 0;
  $balance += $_->setup + $_->recur for $self->cust_bill_pkg_pkgnum($pkgnum);

  $balance -= $_->amount            for $self->cust_bill_pay_pkg($pkgnum);
  $balance -= $_->amount            for $self->cust_credit_bill_pkg($pkgnum);

  $balance = sprintf( "%.2f", $balance);
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

=item hide

Returns true if this invoice should be hidden.  See the
selfservice-hide_invoices-taxclass configuraiton setting.

=cut

sub hide {
  my $self = shift;
  my $conf = $self->conf;
  my $hide_taxclass = $conf->config('selfservice-hide_invoices-taxclass')
    or return '';
  my @cust_bill_pkg = $self->cust_bill_pkg;
  my @part_pkg = grep $_, map $_->part_pkg, @cust_bill_pkg;
  ! grep { $_->taxclass ne $hide_taxclass } @part_pkg;
}

=item apply_payments_and_credits [ OPTION => VALUE ... ]

Applies unapplied payments and credits to this invoice.
Payments with the no_auto_apply flag set will not be applied.

A hash of optional arguments may be passed.  Currently "manual" is supported.
If true, a payment receipt is sent instead of a statement when
'payment_receipt_email' configuration option is set.

If there is an error, returns the error, otherwise returns false.

=cut

sub apply_payments_and_credits {
  my( $self, %options ) = @_;
  my $conf = $self->conf;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  my @payments = grep { $_->unapplied > 0 }
                   grep { !$_->no_auto_apply }
                     $self->cust_main->cust_pay;
  my @credits  = grep { $_->credited > 0 } $self->cust_main->cust_credit;

  if ( $conf->exists('pkg-balances') ) {
    # limit @payments & @credits to those w/ a pkgnum grepped from $self
    my %pkgnums = map { $_ => 1 } map $_->pkgnum, $self->cust_bill_pkg;
    @payments = grep { ! $_->pkgnum || $pkgnums{$_->pkgnum} } @payments;
    @credits  = grep { ! $_->pkgnum || $pkgnums{$_->pkgnum} } @credits;
  }

  while ( $self->owed > 0 and ( @payments || @credits ) ) {

    my $app = '';
    if ( @payments && @credits ) {

      #decide which goes first by weight of top (unapplied) line item

      my @open_lineitems = $self->open_cust_bill_pkg;

      my $max_pay_weight =
        max( map  { $_->part_pkg->pay_weight || 0 }
             grep { $_ }
             map  { $_->cust_pkg }
	          @open_lineitems
	   );
      my $max_credit_weight =
        max( map  { $_->part_pkg->credit_weight || 0 }
	     grep { $_ }
             map  { $_->cust_pkg }
                  @open_lineitems
           );

      #if both are the same... payments first?  it has to be something
      if ( $max_pay_weight >= $max_credit_weight ) {
        $app = 'pay';
      } else {
        $app = 'credit';
      }

    } elsif ( @payments ) {
      $app = 'pay';
    } elsif ( @credits ) {
      $app = 'credit';
    } else {
      die "guru meditation #12 and 35";
    }

    my $unapp_amount;
    if ( $app eq 'pay' ) {

      my $payment = shift @payments;
      $unapp_amount = $payment->unapplied;
      $app = new FS::cust_bill_pay { 'paynum'  => $payment->paynum };
      $app->pkgnum( $payment->pkgnum )
        if $conf->exists('pkg-balances') && $payment->pkgnum;

    } elsif ( $app eq 'credit' ) {

      my $credit = shift @credits;
      $unapp_amount = $credit->credited;
      $app = new FS::cust_credit_bill { 'crednum' => $credit->crednum };
      $app->pkgnum( $credit->pkgnum )
        if $conf->exists('pkg-balances') && $credit->pkgnum;

    } else {
      die "guru meditation #12 and 35";
    }

    my $owed;
    if ( $conf->exists('pkg-balances') && $app->pkgnum ) {
      warn "owed_pkgnum ". $app->pkgnum;
      $owed = $self->owed_pkgnum($app->pkgnum);
    } else {
      $owed = $self->owed;
    }
    next unless $owed > 0;

    warn "min ( $unapp_amount, $owed )\n" if $DEBUG;
    $app->amount( sprintf('%.2f', min( $unapp_amount, $owed ) ) );

    $app->invnum( $self->invnum );

    my $error = $app->insert(%options);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error inserting ". $app->table. " record: $error";
    }
    die $error if $error;

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item send HASHREF

Sends this invoice to the destinations configured for this customer: sends
email, prints and/or faxes.  See L<FS::cust_main_invoice>.

Options can be passed as a hashref.  Positional parameters are no longer
allowed.

I<template>: a suffix for alternate invoices

I<agentnum>: obsolete, now does nothing.

I<from> overrides the default email invoice From: address.

I<amount>: obsolete, does nothing

I<notice_name> overrides "Invoice" as the name of the sent document
(templates from 10/2009 or newer required).

I<lpr> overrides the system 'lpr' option as the command to print a document
from standard input.

=cut

sub send {
  my $self = shift;
  my $opt = ref($_[0]) ? $_[0] : +{ @_ };
  my $conf = $self->conf;

  my $cust_main = $self->cust_main;

  my @invoicing_list = $cust_main->invoicing_list;

  $self->email($opt)
    if ( grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list or !@invoicing_list )
    && ! $cust_main->invoice_noemail;

  $self->print($opt)
    if grep { $_ eq 'POST' } @invoicing_list; #postal

  #this has never been used post-$ORIGINAL_ISP afaik
  $self->fax_invoice($opt)
    if grep { $_ eq 'FAX' } @invoicing_list; #fax

  '';

}

sub email {
  my $self = shift;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    die ref($self). '->email called with positional parameters';
  }

  my $conf = $self->conf;

  my $from = delete $opt->{from};

  # this is where we set the From: address
  $from ||= $self->_agent_invoice_from ||    #XXX should go away
            $conf->invoice_from_full( $self->cust_main->agentnum );

  my @invoicing_list = $self->cust_main->invoicing_list_emailonly;

  if ( ! @invoicing_list ) { #no recipients
    if ( $conf->exists('cust_bill-no_recipients-error') ) {
      die 'No recipients for customer #'. $self->custnum;
    } else {
      #default: better to notify this person than silence
      @invoicing_list = ($from);
    }
  }

  $self->SUPER::email( {
    'from' => $from,
    'to'   => \@invoicing_list,
    %$opt,
  });

}

#this stays here for now because its explicitly used as
# FS::cust_bill::queueable_email
sub queueable_email {
  my %opt = @_;

  my $self = qsearchs('cust_bill', { 'invnum' => $opt{invnum} } )
    or die "invalid invoice number: " . $opt{invnum};

  $self->set('mode', $opt{mode})
    if $opt{mode};

  my %args = map {$_ => $opt{$_}}
             grep { $opt{$_} }
              qw( from notice_name no_coupon template );

  my $error = $self->email( \%args );
  die $error if $error;

}

sub email_subject {
  my $self = shift;
  my $conf = $self->conf;

  #my $template = scalar(@_) ? shift : '';
  #per-template?

  my $subject = $conf->config('invoice_subject', $self->cust_main->agentnum)
                || 'Invoice';

  my $cust_main = $self->cust_main;
  my $name = $cust_main->name;
  my $name_short = $cust_main->name_short;
  my $invoice_number = $self->invnum;
  my $invoice_date = $self->_date_pretty;

  eval qq("$subject");
}

sub pdf_filename {
  my $self = shift;
  'Invoice-'. $self->invnum. '.pdf';
}

=item lpr_data HASHREF

Returns the postscript or plaintext for this invoice as an arrayref.

Options must be passed as a hashref.  Positional parameters are no longer
allowed.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub lpr_data {
  my $self = shift;
  my $conf = $self->conf;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    # nobody does this anyway
    die "FS::cust_bill::lpr_data called with positional parameters";
  }

  my $method = $conf->exists('invoice_latex') ? 'print_ps' : 'print_text';
  [ $self->$method( $opt ) ];
}

=item print HASHREF

Prints this invoice.

Options must be passed as a hashref.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print {
  my $self = shift;
  return if $self->hide;
  my $conf = $self->conf;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    die "FS::cust_bill::print called with positional parameters";
  }

  my $lpr = delete $opt->{lpr};
  if($conf->exists('invoice_print_pdf')) {
    # Add the invoice to the current batch.
    $self->batch_invoice($opt);
  }
  else {
    do_print(
      $self->lpr_data($opt),
      'agentnum' => $self->cust_main->agentnum,
      'lpr'      => $lpr,
    );
  }
}

=item fax_invoice HASHREF

Faxes this invoice.

Options must be passed as a hashref.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub fax_invoice {
  my $self = shift;
  return if $self->hide;
  my $conf = $self->conf;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    die "FS::cust_bill::fax_invoice called with positional parameters";
  }

  die 'FAX invoice destination not (yet?) supported with plain text invoices.'
    unless $conf->exists('invoice_latex');

  my $dialstring = $self->cust_main->getfield('fax');
  #Check $dialstring?

  my $error = send_fax( 'docdata'    => $self->lpr_data($opt),
                        'dialstring' => $dialstring,
                      );
  die $error if $error;

}

=item batch_invoice [ HASHREF ]

Place this invoice into the open batch (see C<FS::bill_batch>).  If there
isn't an open batch, one will be created.

HASHREF may contain any options to be passed to C<print_pdf>.

=cut

sub batch_invoice {
  my ($self, $opt) = @_;
  my $bill_batch = $self->get_open_bill_batch;
  my $cust_bill_batch = FS::cust_bill_batch->new({
      batchnum => $bill_batch->batchnum,
      invnum   => $self->invnum,
  });
  if ( $self->mode ) {
    $opt->{mode} ||= $self->mode;
    $opt->{mode} = $opt->{mode}->modenum if ref $opt->{mode};
  }
  return $cust_bill_batch->insert($opt);
}

=item get_open_batch

Returns the currently open batch as an FS::bill_batch object, creating a new
one if necessary.  (A per-agent batch if invoice_print_pdf-spoolagent is
enabled)

=cut

sub get_open_bill_batch {
  my $self = shift;
  my $conf = $self->conf;
  my $hashref = { status => 'O' };
  $hashref->{'agentnum'} = $conf->exists('invoice_print_pdf-spoolagent')
                             ? $self->cust_main->agentnum
                             : '';
  my $batch = qsearchs('bill_batch', $hashref);
  return $batch if $batch;
  $batch = FS::bill_batch->new($hashref);
  my $error = $batch->insert;
  die $error if $error;
  return $batch;
}

=item ftp_invoice [ TEMPLATENAME ]

Sends this invoice data via FTP.

TEMPLATENAME is unused?

=cut

sub ftp_invoice {
  my $self = shift;
  my $conf = $self->conf;
  my $template = scalar(@_) ? shift : '';

  $self->send_csv(
    'protocol'   => 'ftp',
    'server'     => $conf->config('cust_bill-ftpserver'),
    'username'   => $conf->config('cust_bill-ftpusername'),
    'password'   => $conf->config('cust_bill-ftppassword'),
    'dir'        => $conf->config('cust_bill-ftpdir'),
    'format'     => $conf->config('cust_bill-ftpformat'),
  );
}

=item spool_invoice [ TEMPLATENAME ]

Spools this invoice data (see L<FS::spool_csv>)

TEMPLATENAME is unused?

=cut

sub spool_invoice {
  my $self = shift;
  my $conf = $self->conf;
  my $template = scalar(@_) ? shift : '';

  $self->spool_csv(
    'format'       => $conf->config('cust_bill-spoolformat'),
    'agent_spools' => $conf->exists('cust_bill-spoolagent'),
  );
}

=item send_csv OPTION => VALUE, ...

Sends invoice as a CSV data-file to a remote host with the specified protocol.

Options are:

protocol - currently only "ftp"
server
username
password
dir

The file will be named "N-YYYYMMDDHHMMSS.csv" where N is the invoice number
and YYMMDDHHMMSS is a timestamp.

See L</print_csv> for a description of the output format.

=cut

sub send_csv {
  my($self, %opt) = @_;

  #create file(s)

  my $spooldir = "/usr/local/etc/freeside/export.". datasrc. "/cust_bill";
  mkdir $spooldir, 0700 unless -d $spooldir;

  # don't localize dates here, they're a defined format
  my $tracctnum = $self->invnum. time2str('-%Y%m%d%H%M%S', time);
  my $file = "$spooldir/$tracctnum.csv";

  my ( $header, $detail ) = $self->print_csv(%opt, 'tracctnum' => $tracctnum );

  open(CSV, ">$file") or die "can't open $file: $!";
  print CSV $header;

  print CSV $detail;

  close CSV;

  my $net;
  if ( $opt{protocol} eq 'ftp' ) {
    eval "use Net::FTP;";
    die $@ if $@;
    $net = Net::FTP->new($opt{server}) or die @$;
  } else {
    die "unknown protocol: $opt{protocol}";
  }

  $net->login( $opt{username}, $opt{password} )
    or die "can't FTP to $opt{username}\@$opt{server}: login error: $@";

  $net->binary or die "can't set binary mode";

  $net->cwd($opt{dir}) or die "can't cwd to $opt{dir}";

  $net->put($file) or die "can't put $file: $!";

  $net->quit;

  unlink $file;

}

=item spool_csv

Spools CSV invoice data.

Options are:

=over 4

=item format - any of FS::Misc::::Invoicing::spool_formats

=item dest - if set (to POST, EMAIL or FAX), only sends spools invoices if the
customer has the corresponding invoice destinations set (see
L<FS::cust_main_invoice>).

=item agent_spools - if set to a true value, will spool to per-agent files
rather than a single global file

=item upload_targetnum - if set to a target (see L<FS::upload_target>), will
append to that spool.  L<FS::Cron::upload> will then send the spool file to
that destination.

=item balanceover - if set, only spools the invoice if the total amount owed on
this invoice and all older invoices is greater than the specified amount.

=item time - the "current time".  Controls the printing of past due messages
in the ICS format.

=back

=cut

sub spool_csv {
  my($self, %opt) = @_;

  my $time = $opt{'time'} || time;
  my $cust_main = $self->cust_main;

  if ( $opt{'dest'} ) {
    my %invoicing_list = map { /^(POST|FAX)$/ or 'EMAIL' =~ /^(.*)$/; $1 => 1 }
                             $cust_main->invoicing_list;
    return 'N/A' unless $invoicing_list{$opt{'dest'}}
                     || ! keys %invoicing_list;
  }

  if ( $opt{'balanceover'} ) {
    return 'N/A'
      if $cust_main->total_owed_date($self->_date) < $opt{'balanceover'};
  }

  my $spooldir = "/usr/local/etc/freeside/export.". datasrc. "/cust_bill";
  mkdir $spooldir, 0700 unless -d $spooldir;

  my $tracctnum = $self->invnum. time2str('-%Y%m%d%H%M%S', $time);

  my $file;
  if ( $opt{'agent_spools'} ) {
    $file = 'agentnum'.$cust_main->agentnum;
  } else {
    $file = 'spool';
  }

  if ( $opt{'upload_targetnum'} ) {
    $spooldir .= '/target'.$opt{'upload_targetnum'};
    mkdir $spooldir, 0700 unless -d $spooldir;
  } # otherwise it just goes into export.xxx/cust_bill

  if ( lc($opt{'format'}) eq 'billco' ) {
    $file .= '-header';
  }

  $file = "$spooldir/$file.csv";

  my ( $header, $detail ) = $self->print_csv(%opt, 'tracctnum' => $tracctnum);

  open(CSV, ">>$file") or die "can't open $file: $!";
  flock(CSV, LOCK_EX);
  seek(CSV, 0, 2);

  print CSV $header;

  if ( lc($opt{'format'}) eq 'billco' ) {

    flock(CSV, LOCK_UN);
    close CSV;

    $file =~ s/-header.csv$/-detail.csv/;

    open(CSV,">>$file") or die "can't open $file: $!";
    flock(CSV, LOCK_EX);
    seek(CSV, 0, 2);
  }

  print CSV $detail if defined($detail);

  flock(CSV, LOCK_UN);
  close CSV;

  return '';

}

=item print_csv OPTION => VALUE, ...

Returns CSV data for this invoice.

Options are:

format - 'default', 'billco', 'oneline', 'bridgestone'

Returns a list consisting of two scalars.  The first is a single line of CSV
header information for this invoice.  The second is one or more lines of CSV
detail information for this invoice.

If I<format> is not specified or "default", the fields of the CSV file are as
follows:

record_type, invnum, custnum, _date, charged, first, last, company, address1,
address2, city, state, zip, country, pkg, setup, recur, sdate, edate

=over 4

=item record type - B<record_type> is either C<cust_bill> or C<cust_bill_pkg>

B<record_type> is C<cust_bill> for the initial header line only.  The
last five fields (B<pkg> through B<edate>) are irrelevant, and all other
fields are filled in.

B<record_type> is C<cust_bill_pkg> for detail lines.  Only the first two fields
(B<record_type> and B<invnum>) and the last five fields (B<pkg> through B<edate>)
are filled in.

=item invnum - invoice number

=item custnum - customer number

=item _date - invoice date

=item charged - total invoice amount

=item first - customer first name

=item last - customer first name

=item company - company name

=item address1 - address line 1

=item address2 - address line 1

=item city

=item state

=item zip

=item country

=item pkg - line item description

=item setup - line item setup fee (one or both of B<setup> and B<recur> will be defined)

=item recur - line item recurring fee (one or both of B<setup> and B<recur> will be defined)

=item sdate - start date for recurring fee

=item edate - end date for recurring fee

=back

If I<format> is "billco", the fields of the header CSV file are as follows:

  +-------------------------------------------------------------------+
  |                        FORMAT HEADER FILE                         |
  |-------------------------------------------------------------------|
  | Field | Description                   | Name       | Type | Width |
  | 1     | N/A-Leave Empty               | RC         | CHAR |     2 |
  | 2     | N/A-Leave Empty               | CUSTID     | CHAR |    15 |
  | 3     | Transaction Account No        | TRACCTNUM  | CHAR |    15 |
  | 4     | Transaction Invoice No        | TRINVOICE  | CHAR |    15 |
  | 5     | Transaction Zip Code          | TRZIP      | CHAR |     5 |
  | 6     | Transaction Company Bill To   | TRCOMPANY  | CHAR |    30 |
  | 7     | Transaction Contact Bill To   | TRNAME     | CHAR |    30 |
  | 8     | Additional Address Unit Info  | TRADDR1    | CHAR |    30 |
  | 9     | Bill To Street Address        | TRADDR2    | CHAR |    30 |
  | 10    | Ancillary Billing Information | TRADDR3    | CHAR |    30 |
  | 11    | Transaction City Bill To      | TRCITY     | CHAR |    20 |
  | 12    | Transaction State Bill To     | TRSTATE    | CHAR |     2 |
  | 13    | Bill Cycle Close Date         | CLOSEDATE  | CHAR |    10 |
  | 14    | Bill Due Date                 | DUEDATE    | CHAR |    10 |
  | 15    | Previous Balance              | BALFWD     | NUM* |     9 |
  | 16    | Pmt/CR Applied                | CREDAPPLY  | NUM* |     9 |
  | 17    | Total Current Charges         | CURRENTCHG | NUM* |     9 |
  | 18    | Total Amt Due                 | TOTALDUE   | NUM* |     9 |
  | 19    | Total Amt Due                 | AMTDUE     | NUM* |     9 |
  | 20    | 30 Day Aging                  | AMT30      | NUM* |     9 |
  | 21    | 60 Day Aging                  | AMT60      | NUM* |     9 |
  | 22    | 90 Day Aging                  | AMT90      | NUM* |     9 |
  | 23    | Y/N                           | AGESWITCH  | CHAR |     1 |
  | 24    | Remittance automation         | SCANLINE   | CHAR |   100 |
  | 25    | Total Taxes & Fees            | TAXTOT     | NUM* |     9 |
  | 26    | Customer Reference Number     | CUSTREF    | CHAR |    15 |
  | 27    | Federal Tax***                | FEDTAX     | NUM* |     9 |
  | 28    | State Tax***                  | STATETAX   | NUM* |     9 |
  | 29    | Other Taxes & Fees***         | OTHERTAX   | NUM* |     9 |
  +-------+-------------------------------+------------+------+-------+

If I<format> is "billco", the fields of the detail CSV file are as follows:

                                  FORMAT FOR DETAIL FILE
        |                            |           |      |
  Field | Description                | Name      | Type | Width
  1     | N/A-Leave Empty            | RC        | CHAR |     2
  2     | N/A-Leave Empty            | CUSTID    | CHAR |    15
  3     | Account Number             | TRACCTNUM | CHAR |    15
  4     | Invoice Number             | TRINVOICE | CHAR |    15
  5     | Line Sequence (sort order) | LINESEQ   | NUM  |     6
  6     | Transaction Detail         | DETAILS   | CHAR |   100
  7     | Amount                     | AMT       | NUM* |     9
  8     | Line Format Control**      | LNCTRL    | CHAR |     2
  9     | Grouping Code              | GROUP     | CHAR |     2
  10    | User Defined               | ACCT CODE | CHAR |    15

If format is 'oneline', there is no detail file.  Each invoice has a
header line only, with the fields:

Agent number, agent name, customer number, first name, last name, address
line 1, address line 2, city, state, zip, invoice date, invoice number,
amount charged, amount due, previous balance, due date.

and then, for each line item, three columns containing the package number,
description, and amount.

If format is 'bridgestone', there is no detail file.  Each invoice has a
header line with the following fields in a fixed-width format:

Customer number (in display format), date, name (first last), company,
address 1, address 2, city, state, zip.

This is a mailing list format, and has no per-invoice fields.  To avoid
sending redundant notices, the spooling event should have a "once" or
"once_percust_every" condition.

=cut

sub print_csv {
  my($self, %opt) = @_;

  eval "use Text::CSV_XS";
  die $@ if $@;

  my $cust_main = $self->cust_main;

  my $csv = Text::CSV_XS->new({'always_quote'=>1});
  my $format = lc($opt{'format'});

  my $time = $opt{'time'} || time;

  $self->set('_template', $opt{template})
    if exists $opt{template};

  my $tracctnum = ''; #leaking out from billco-specific sections :/
  if ( $format eq 'billco' ) {

    my $account_num =
      $self->conf->config('billco-account_num', $cust_main->agentnum);

    $tracctnum = $account_num eq 'display_custnum'
                   ? $cust_main->display_custnum
                   : $opt{'tracctnum'};

    my $taxtotal = 0;
    $taxtotal += $_->{'amount'} foreach $self->_items_tax;

    my $duedate = $self->due_date2str('%m/%d/%Y'); # hardcoded, NOT date_format

    my( $previous_balance, @unused ) = $self->previous; #previous balance

    my $pmt_cr_applied = 0;
    $pmt_cr_applied += $_->{'amount'}
      foreach ( $self->_items_payments(%opt), $self->_items_credits(%opt) ) ;

    my $totaldue = sprintf('%.2f', $self->owed + $previous_balance);

    $csv->combine(
      '',                         #  1 | N/A-Leave Empty               CHAR   2
      '',                         #  2 | N/A-Leave Empty               CHAR  15
      $tracctnum,                 #  3 | Transaction Account No        CHAR  15
      $self->invnum,              #  4 | Transaction Invoice No        CHAR  15
      $cust_main->zip,            #  5 | Transaction Zip Code          CHAR   5
      $cust_main->company,        #  6 | Transaction Company Bill To   CHAR  30
      #$cust_main->payname,        #  7 | Transaction Contact Bill To   CHAR  30
      $cust_main->contact,        #  7 | Transaction Contact Bill To   CHAR  30
      $cust_main->address2,       #  8 | Additional Address Unit Info  CHAR  30
      $cust_main->address1,       #  9 | Bill To Street Address        CHAR  30
      '',                         # 10 | Ancillary Billing Information CHAR  30
      $cust_main->city,           # 11 | Transaction City Bill To      CHAR  20
      $cust_main->state,          # 12 | Transaction State Bill To     CHAR   2

      # XXX ?
      time2str("%m/%d/%Y", $self->_date), # 13 | Bill Cycle Close Date CHAR  10

      # XXX ?
      $duedate,                   # 14 | Bill Due Date                 CHAR  10

      $previous_balance,          # 15 | Previous Balance              NUM*   9
      $pmt_cr_applied,            # 16 | Pmt/CR Applied                NUM*   9
      sprintf("%.2f", $self->charged), # 17 | Total Current Charges    NUM*   9
      $totaldue,                  # 18 | Total Amt Due                 NUM*   9
      $totaldue,                  # 19 | Total Amt Due                 NUM*   9
      '',                         # 20 | 30 Day Aging                  NUM*   9
      '',                         # 21 | 60 Day Aging                  NUM*   9
      '',                         # 22 | 90 Day Aging                  NUM*   9
      'N',                        # 23 | Y/N                           CHAR   1
      '',                         # 24 | Remittance automation         CHAR 100
      $taxtotal,                  # 25 | Total Taxes & Fees            NUM*   9
      $self->custnum,             # 26 | Customer Reference Number     CHAR  15
      '0',                        # 27 | Federal Tax***                NUM*   9
      sprintf("%.2f", $taxtotal), # 28 | State Tax***                  NUM*   9
      '0',                        # 29 | Other Taxes & Fees***         NUM*   9
    );

  } elsif ( $format eq 'oneline' ) { #name

    my ($previous_balance) = $self->previous;
    $previous_balance = sprintf('%.2f', $previous_balance);
    my $totaldue = sprintf('%.2f', $self->owed + $previous_balance);
    my @items = map {
                      $_->{pkgnum},
                      $_->{description},
                      $_->{amount}
                    }
                  $self->_items_pkg, #_items_nontax?  no sections or anything
                                     # with this format
                  $self->_items_tax;

    $csv->combine(
      $cust_main->agentnum,
      $cust_main->agent->agent,
      $self->custnum,
      $cust_main->first,
      $cust_main->last,
      $cust_main->company,
      $cust_main->address1,
      $cust_main->address2,
      $cust_main->city,
      $cust_main->state,
      $cust_main->zip,

      # invoice fields
      time2str("%x", $self->_date),
      $self->invnum,
      $self->charged,
      $totaldue,
      $previous_balance,
      $self->due_date2str("%x"),

      @items,
    );

  } elsif ( $format eq 'bridgestone' ) {

    # bypass the CSV stuff and just return this
    my $longdate = time2str('%B %d, %Y', $time); #current time, right?
    my $zip = $cust_main->zip;
    $zip =~ s/\D//;
    my $prefix = $self->conf->config('bridgestone-prefix', $cust_main->agentnum)
      || '';
    return (
      sprintf(
        "%-5s%-15s%-20s%-30s%-30s%-30s%-30s%-20s%-2s%-9s\n",
        $prefix,
        $cust_main->display_custnum,
        $longdate,
        uc(substr($cust_main->contact_firstlast,0,30)),
        uc(substr($cust_main->company          ,0,30)),
        uc(substr($cust_main->address1         ,0,30)),
        uc(substr($cust_main->address2         ,0,30)),
        uc(substr($cust_main->city             ,0,20)),
        uc($cust_main->state),
        $zip
      ),
      '' #detail
      );

  } elsif ( $format eq 'ics' ) {

    my $bill = $cust_main->bill_location;
    my $zip = $bill->zip;
    my $zip4 = '';

    $zip =~ s/\D//;
    if ( $zip =~ /^(\d{5})(\d{4})$/ ) {
      $zip = $1;
      $zip4 = $2;
    }

    # minor false laziness with print_generic
    my ($previous_balance) = $self->previous;
    my $balance_due = $self->owed + $previous_balance;
    my $payment_total = sum(0, map { $_->{'amount'} } $self->_items_payments);
    my $credit_total  = sum(0, map { $_->{'amount'} } $self->_items_credits);

    my $past_due = '';
    if ( $self->due_date and $time >= $self->due_date ) {
      $past_due = sprintf('Past due:$%0.2f Due Immediately', $balance_due);
    }

    # again, bypass CSV
    my $header = sprintf(
      '%-10s%-30s%-48s%-2s%-50s%-30s%-30s%-25s%-2s%-5s%-4s%-8s%-8s%-10s%-10s%-10s%-10s%-10s%-10s%-480s%-35s',
      $cust_main->display_custnum, #BID
      uc($cust_main->first), #FNAME
      uc($cust_main->last), #LNAME
      '00', #BATCH, should this ever be anything else?
      uc($cust_main->company), #COMP
      uc($bill->address1), #STREET1
      uc($bill->address2), #STREET2
      uc($bill->city), #CITY
      uc($bill->state), #STATE
      $zip,
      $zip4,
      time2str('%Y%m%d', $self->_date), #BILL_DATE
      $self->due_date2str('%Y%m%d'), #DUE_DATE,
      ( map {sprintf('%0.2f', $_)}
        $balance_due, #AMNT_DUE
        $previous_balance, #PREV_BAL
        $payment_total, #PYMT_RCVD
        $credit_total, #CREDITS
        $previous_balance, #BEG_BAL--is this correct?
        $self->charged, #NEW_CHRG
      ),
      'img01', #MRKT_MSG?
      $past_due, #PAST_MSG
    );

    my @details;
    my %svc_class = ('' => ''); # maybe cache this more persistently?

    foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {

      my $show_pkgnum = $cust_bill_pkg->pkgnum || '';
      my $cust_pkg = $cust_bill_pkg->cust_pkg if $show_pkgnum;

      if ( $cust_pkg ) {

        my @dates = ( $self->_date, undef );
        if ( my $prev = $cust_bill_pkg->previous_cust_bill_pkg ) {
          $dates[1] = $prev->sdate; #questionable
        }

        # generate an 01 detail for each service
        my @svcs = $cust_pkg->h_cust_svc(@dates, 'I');
        foreach my $cust_svc ( @svcs ) {
          $show_pkgnum = ''; # hide it if we're showing svcnums

          my $svcpart = $cust_svc->svcpart;
          if (!exists($svc_class{$svcpart})) {
            my $classnum = $cust_svc->part_svc->classnum;
            my $part_svc_class = FS::part_svc_class->by_key($classnum)
              if $classnum;
            $svc_class{$svcpart} = $part_svc_class ?
                                   $part_svc_class->classname :
                                   '';
          }

          my @h_label = $cust_svc->label(@dates, 'I');
          push @details, sprintf('01%-9s%-20s%-47s',
            $cust_svc->svcnum,
            $svc_class{$svcpart},
            $h_label[1],
          );
        } #foreach $cust_svc
      } #if $cust_pkg

      my $desc = $cust_bill_pkg->desc; # itemdesc or part_pkg.pkg
      if ($cust_bill_pkg->recur > 0) {
        $desc .= ' '.time2str('%d-%b-%Y', $cust_bill_pkg->sdate).' to '.
                     time2str('%d-%b-%Y', $cust_bill_pkg->edate - 86400);
      }
      push @details, sprintf('02%-6s%-60s%-10s',
        $show_pkgnum,
        $desc,
        sprintf('%0.2f', $cust_bill_pkg->setup + $cust_bill_pkg->recur),
      );
    } #foreach $cust_bill_pkg

    # Tag this row so that we know whether this is one page (1), two pages
    # (2), # or "big" (B).  The tag will be stripped off before uploading.
    if ( scalar(@details) < 12 ) {
      push @details, '1';
    } elsif ( scalar(@details) < 58 ) {
      push @details, '2';
    } else {
      push @details, 'B';
    }

    return join('', $header, @details, "\n");

  } else { # default

    $csv->combine(
      'cust_bill',
      $self->invnum,
      $self->custnum,
      time2str("%x", $self->_date),
      sprintf("%.2f", $self->charged),
      ( map { $cust_main->getfield($_) }
          qw( first last company address1 address2 city state zip country ) ),
      map { '' } (1..5),
    ) or die "can't create csv";
  }

  my $header = $csv->string. "\n";

  my $detail = '';
  if ( lc($opt{'format'}) eq 'billco' ) {

    my $lineseq = 0;
    my %items_opt = ( format => 'template',
                      escape_function => sub { shift } );
    # I don't know what characters billco actually tolerates in spool entries.
    # Text::CSV will take care of delimiters, though.

    my @items = ( $self->_items_pkg(%items_opt),
                  $self->_items_fee(%items_opt) );
    foreach my $item (@items) {

      my $description = $item->{'description'};
      if ( $item->{'_is_discount'} and exists($item->{ext_description}[0]) ) {
        $description .= ': ' . $item->{ext_description}[0];
      }

      $csv->combine(
        '',                     #  1 | N/A-Leave Empty            CHAR   2
        '',                     #  2 | N/A-Leave Empty            CHAR  15
        $tracctnum,             #  3 | Account Number             CHAR  15
        $self->invnum,          #  4 | Invoice Number             CHAR  15
        $lineseq++,             #  5 | Line Sequence (sort order) NUM    6
        $description,           #  6 | Transaction Detail         CHAR 100
        $item->{'amount'},      #  7 | Amount                     NUM*   9
        '',                     #  8 | Line Format Control**      CHAR   2
        '',                     #  9 | Grouping Code              CHAR   2
        '',                     # 10 | User Defined               CHAR  15
      );

      $detail .= $csv->string. "\n";

    }

  } elsif ( lc($opt{'format'}) eq 'oneline' ) {

    #do nothing

  } else {

    foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {

      my($pkg, $setup, $recur, $sdate, $edate);
      if ( $cust_bill_pkg->pkgnum ) {

        ($pkg, $setup, $recur, $sdate, $edate) = (
          $cust_bill_pkg->part_pkg->pkg,
          ( $cust_bill_pkg->setup != 0
            ? sprintf("%.2f", $cust_bill_pkg->setup )
            : '' ),
          ( $cust_bill_pkg->recur != 0
            ? sprintf("%.2f", $cust_bill_pkg->recur )
            : '' ),
          ( $cust_bill_pkg->sdate
            ? time2str("%x", $cust_bill_pkg->sdate)
            : '' ),
          ($cust_bill_pkg->edate
            ? time2str("%x", $cust_bill_pkg->edate)
            : '' ),
        );

      } else { #pkgnum tax
        next unless $cust_bill_pkg->setup != 0;
        $pkg = $cust_bill_pkg->desc;
        $setup = sprintf('%10.2f', $cust_bill_pkg->setup );
        ( $sdate, $edate ) = ( '', '' );
      }

      $csv->combine(
        'cust_bill_pkg',
        $self->invnum,
        ( map { '' } (1..11) ),
        ($pkg, $setup, $recur, $sdate, $edate)
      ) or die "can't create csv";

      $detail .= $csv->string. "\n";

    }

  }

  ( $header, $detail );

}

sub comp {
  croak 'cust_bill->comp is deprecated (COMP payments are deprecated)';
}

=item realtime_card

Attempts to pay this invoice with a credit card payment via a
Business::OnlinePayment realtime gateway.  See
http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment
for supported processors.

=cut

sub realtime_card {
  my $self = shift;
  $self->realtime_bop( 'CC', @_ );
}

=item realtime_ach

Attempts to pay this invoice with an electronic check (ACH) payment via a
Business::OnlinePayment realtime gateway.  See
http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment
for supported processors.

=cut

sub realtime_ach {
  my $self = shift;
  $self->realtime_bop( 'ECHECK', @_ );
}

=item realtime_lec

Attempts to pay this invoice with phone bill (LEC) payment via a
Business::OnlinePayment realtime gateway.  See
http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment
for supported processors.

=cut

sub realtime_lec {
  my $self = shift;
  $self->realtime_bop( 'LEC', @_ );
}

sub realtime_bop {
  my( $self, $method ) = (shift,shift);
  my $conf = $self->conf;
  my %opt = @_;

  my $cust_main = $self->cust_main;
  my $balance = $cust_main->balance;
  my $amount = ( $balance < $self->owed ) ? $balance : $self->owed;
  $amount = sprintf("%.2f", $amount);
  return "not run (balance $balance)" unless $amount > 0;

  my $description = 'Internet Services';
  if ( $conf->exists('business-onlinepayment-description') ) {
    my $dtempl = $conf->config('business-onlinepayment-description');

    my $agent_obj = $cust_main->agent
      or die "can't retreive agent for $cust_main (agentnum ".
             $cust_main->agentnum. ")";
    my $agent = $agent_obj->agent;
    my $pkgs = join(', ',
      map { $_->part_pkg->pkg }
        grep { $_->pkgnum } $self->cust_bill_pkg
    );
    $description = eval qq("$dtempl");
  }

  $cust_main->realtime_bop($method, $amount,
    'description' => $description,
    'invnum'      => $self->invnum,
#this didn't do what we want, it just calls apply_payments_and_credits
#    'apply'       => 1,
    'apply_to_invoice' => 1,
    %opt,
 #what we want:
 #this changes application behavior: auto payments
                        #triggered against a specific invoice are now applied
                        #to that invoice instead of oldest open.
                        #seem okay to me...
  );

}

=item batch_card OPTION => VALUE...

Adds a payment for this invoice to the pending credit card batch (see
L<FS::cust_pay_batch>), or, if the B<realtime> option is set to a true value,
runs the payment using a realtime gateway.

=cut

sub batch_card {
  my ($self, %options) = @_;
  my $cust_main = $self->cust_main;

  $options{invnum} = $self->invnum;

  $cust_main->batch_card(%options);
}

sub _agent_template {
  my $self = shift;
  $self->cust_main->agent_template;
}

sub _agent_invoice_from {
  my $self = shift;
  $self->cust_main->agent_invoice_from;
}

=item invoice_barcode DIR_OR_FALSE

Generates an invoice barcode PNG. If DIR_OR_FALSE is a true value,
it is taken as the temp directory where the PNG file will be generated and the
PNG file name is returned. Otherwise, the PNG image itself is returned.

=cut

sub invoice_barcode {
    my ($self, $dir) = (shift,shift);

    my $gdbar = new GD::Barcode('Code39',$self->invnum);
	die "can't create barcode: " . $GD::Barcode::errStr unless $gdbar;
    my $gd = $gdbar->plot(Height => 30);

    if($dir) {
	my $bh = new File::Temp( TEMPLATE => 'barcode.'. $self->invnum. '.XXXXXXXX',
			   DIR      => $dir,
			   SUFFIX   => '.png',
			   UNLINK   => 0,
			 ) or die "can't open temp file: $!\n";
	print $bh $gd->png or die "cannot write barcode to file: $!\n";
	my $png_file = $bh->filename;
	close $bh;
	return $png_file;
    }
    return $gd->png;
}

=item invnum_date_pretty

Returns a string with the invoice number and date, for example:
"Invoice #54 (3/20/2008)".

Intended for back-end context, with regard to translation and date formatting.

=cut

#note: this uses _date_pretty_unlocalized because _date_pretty is too expensive
# for backend use (and also does the wrong thing, localizing for end customer
# instead of backoffice configured date format)
sub invnum_date_pretty {
  my $self = shift;
  #$self->mt('Invoice #').
  'Invoice #'. #XXX should be translated ala web UI user (not invoice customer)
    $self->invnum. ' ('. $self->_date_pretty_unlocalized. ')';
}

#sub _items_extra_usage_sections {
#  my $self = shift;
#  my $escape = shift;
#
#  my %sections = ();
#
#  my %usage_class =  map{ $_->classname, $_ } qsearch('usage_class', {});
#  foreach my $cust_bill_pkg ( $self->cust_bill_pkg )
#  {
#    next unless $cust_bill_pkg->pkgnum > 0;
#
#    foreach my $section ( keys %usage_class ) {
#
#      my $usage = $cust_bill_pkg->usage($section);
#
#      next unless $usage && $usage > 0;
#
#      $sections{$section} ||= 0;
#      $sections{$section} += $usage;
#
#    }
#
#  }
#
#  map { { 'description' => &{$escape}($_),
#          'subtotal'    => $sections{$_},
#          'summarized'  => '',
#          'tax_section' => '',
#        }
#      }
#    sort {$usage_class{$a}->weight <=> $usage_class{$b}->weight} keys %sections;
#
#}

sub _items_extra_usage_sections {
  my $self = shift;
  my $conf = $self->conf;
  my $escape = shift;
  my $format = shift;

  my %sections = ();
  my %classnums = ();
  my %lines = ();

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 40;

  my %usage_class =  map { $_->classnum => $_ } qsearch( 'usage_class', {} );
  foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
    next unless $cust_bill_pkg->pkgnum > 0;

    foreach my $classnum ( keys %usage_class ) {
      my $section = $usage_class{$classnum}->classname;
      $classnums{$section} = $classnum;

      foreach my $detail ( $cust_bill_pkg->cust_bill_pkg_detail($classnum) ) {
        my $amount = $detail->amount;
        next unless $amount && $amount > 0;

        $sections{$section} ||= { 'subtotal'=>0, 'calls'=>0, 'duration'=>0 };
        $sections{$section}{amount} += $amount;  #subtotal
        $sections{$section}{calls}++;
        $sections{$section}{duration} += $detail->duration;

        my $desc = $detail->regionname;
        my $description = $desc;
        $description = substr($desc, 0, $maxlength). '...'
          if $format eq 'latex' && length($desc) > $maxlength;

        $lines{$section}{$desc} ||= {
          description     => &{$escape}($description),
          #pkgpart         => $part_pkg->pkgpart,
          pkgnum          => $cust_bill_pkg->pkgnum,
          ref             => '',
          amount          => 0,
          calls           => 0,
          duration        => 0,
          #unit_amount     => $cust_bill_pkg->unitrecur,
          quantity        => $cust_bill_pkg->quantity,
          product_code    => 'N/A',
          ext_description => [],
        };

        $lines{$section}{$desc}{amount} += $amount;
        $lines{$section}{$desc}{calls}++;
        $lines{$section}{$desc}{duration} += $detail->duration;

      }
    }
  }

  my %sectionmap = ();
  foreach (keys %sections) {
    my $usage_class = $usage_class{$classnums{$_}};
    $sectionmap{$_} = { 'description' => &{$escape}($_),
                        'amount'    => $sections{$_}{amount},    #subtotal
                        'calls'       => $sections{$_}{calls},
                        'duration'    => $sections{$_}{duration},
                        'summarized'  => '',
                        'tax_section' => '',
                        'sort_weight' => $usage_class->weight,
                        ( $usage_class->format
                          ? ( map { $_ => $usage_class->$_($format) }
                              qw( description_generator header_generator total_generator total_line_generator )
                            )
                          : ()
                        ),
                      };
  }

  my @sections = sort { $a->{sort_weight} <=> $b->{sort_weight} }
                 values %sectionmap;

  my @lines = ();
  foreach my $section ( keys %lines ) {
    foreach my $line ( keys %{$lines{$section}} ) {
      my $l = $lines{$section}{$line};
      $l->{section}     = $sectionmap{$section};
      $l->{amount}      = sprintf( "%.2f", $l->{amount} );
      #$l->{unit_amount} = sprintf( "%.2f", $l->{unit_amount} );
      push @lines, $l;
    }
  }

  return(\@sections, \@lines);

}

sub _did_summary {
    my $self = shift;
    my $end = $self->_date;

    # start at date of previous invoice + 1 second or 0 if no previous invoice
    my $start = $self->scalar_sql("SELECT max(_date) FROM cust_bill WHERE custnum = ? and invnum != ?",$self->custnum,$self->invnum);
    $start = 0 if !$start;
    $start++;

    my $cust_main = $self->cust_main;
    my @pkgs = $cust_main->all_pkgs;
    my($num_activated,$num_deactivated,$num_portedin,$num_portedout,$minutes)
	= (0,0,0,0,0);
    my @seen = ();
    foreach my $pkg ( @pkgs ) {
	my @h_cust_svc = $pkg->h_cust_svc($end);
	foreach my $h_cust_svc ( @h_cust_svc ) {
	    next if grep {$_ eq $h_cust_svc->svcnum} @seen;
	    next unless $h_cust_svc->part_svc->svcdb eq 'svc_phone';

	    my $inserted = $h_cust_svc->date_inserted;
	    my $deleted = $h_cust_svc->date_deleted;
	    my $phone_inserted = $h_cust_svc->h_svc_x($inserted+5);
	    my $phone_deleted;
	    $phone_deleted =  $h_cust_svc->h_svc_x($deleted) if $deleted;

# DID either activated or ported in; cannot be both for same DID simultaneously
	    if ($inserted >= $start && $inserted <= $end && $phone_inserted
		&& (!$phone_inserted->lnp_status
		    || $phone_inserted->lnp_status eq ''
		    || $phone_inserted->lnp_status eq 'native')) {
		$num_activated++;
	    }
	    else { # this one not so clean, should probably move to (h_)svc_phone
                 local($FS::Record::qsearch_qualify_columns) = 0;
		 my $phone_portedin = qsearchs( 'h_svc_phone',
		      { 'svcnum' => $h_cust_svc->svcnum,
			'lnp_status' => 'portedin' },
		      FS::h_svc_phone->sql_h_searchs($end),
		    );
		 $num_portedin++ if $phone_portedin;
	    }

# DID either deactivated or ported out;	cannot be both for same DID simultaneously
	    if($deleted >= $start && $deleted <= $end && $phone_deleted
		&& (!$phone_deleted->lnp_status
		    || $phone_deleted->lnp_status ne 'portingout')) {
		$num_deactivated++;
	    }
	    elsif($deleted >= $start && $deleted <= $end && $phone_deleted
		&& $phone_deleted->lnp_status
		&& $phone_deleted->lnp_status eq 'portingout') {
		$num_portedout++;
	    }

	    # increment usage minutes
        if ( $phone_inserted ) {
            my @cdrs = $phone_inserted->get_cdrs('begin'=>$start,'end'=>$end,'billsec_sum'=>1);
            $minutes = $cdrs[0]->billsec_sum if scalar(@cdrs) == 1;
        }
        else {
            warn "WARNING: no matching h_svc_phone insert record for insert time $inserted, svcnum " . $h_cust_svc->svcnum;
        }

	    # don't look at this service again
	    push @seen, $h_cust_svc->svcnum;
	}
    }

    $minutes = sprintf("%d", $minutes);
    ("Activated: $num_activated  Ported-In: $num_portedin  Deactivated: "
	. "$num_deactivated  Ported-Out: $num_portedout ",
	    "Total Minutes: $minutes");
}

sub _items_accountcode_cdr {
    my $self = shift;
    my $escape = shift;
    my $format = shift;

    my $section = { 'amount'        => 0,
                    'calls'         => 0,
                    'duration'      => 0,
                    'sort_weight'   => '',
                    'phonenum'      => '',
                    'description'   => 'Usage by Account Code',
                    'post_total'    => '',
                    'summarized'    => '',
                    'header'        => '',
                  };
    my @lines;
    my %accountcodes = ();

    foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
        next unless $cust_bill_pkg->pkgnum > 0;

        my @header = $cust_bill_pkg->details_header;
        next unless scalar(@header);
        $section->{'header'} = join(',',@header);

        foreach my $detail ( $cust_bill_pkg->cust_bill_pkg_detail ) {

            $section->{'header'} = $detail->formatted('format' => $format)
                if($detail->detail eq $section->{'header'});

            my $accountcode = $detail->accountcode;
            next unless $accountcode;

            my $amount = $detail->amount;
            next unless $amount && $amount > 0;

            $accountcodes{$accountcode} ||= {
                    description => $accountcode,
                    pkgnum      => '',
                    ref         => '',
                    amount      => 0,
                    calls       => 0,
                    duration    => 0,
                    quantity    => '',
                    product_code => 'N/A',
                    section     => $section,
                    ext_description => [ $section->{'header'} ],
                    detail_temp => [],
            };

            $section->{'amount'} += $amount;
            $accountcodes{$accountcode}{'amount'} += $amount;
            $accountcodes{$accountcode}{calls}++;
            $accountcodes{$accountcode}{duration} += $detail->duration;
            push @{$accountcodes{$accountcode}{detail_temp}}, $detail;
        }
    }

    foreach my $l ( values %accountcodes ) {
        $l->{amount} = sprintf( "%.2f", $l->{amount} );
        my @sorted_detail = sort { $a->startdate <=> $b->startdate } @{$l->{detail_temp}};
        foreach my $sorted_detail ( @sorted_detail ) {
            push @{$l->{ext_description}}, $sorted_detail->formatted('format'=>$format);
        }
        delete $l->{detail_temp};
        push @lines, $l;
    }

    my @sorted_lines = sort { $a->{'description'} <=> $b->{'description'} } @lines;

    return ($section,\@sorted_lines);
}

sub _items_svc_phone_sections {
  my $self = shift;
  my $conf = $self->conf;
  my $escape = shift;
  my $format = shift;

  my %sections = ();
  my %classnums = ();
  my %lines = ();

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 40;

  my %usage_class =  map { $_->classnum => $_ } qsearch( 'usage_class', {} );
  $usage_class{''} ||= new FS::usage_class { 'classname' => '', 'weight' => 0 };

  foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
    next unless $cust_bill_pkg->pkgnum > 0;

    my @header = $cust_bill_pkg->details_header;
    next unless scalar(@header);

    foreach my $detail ( $cust_bill_pkg->cust_bill_pkg_detail ) {

      my $phonenum = $detail->phonenum;
      next unless $phonenum;

      my $amount = $detail->amount;
      next unless $amount && $amount > 0;

      $sections{$phonenum} ||= { 'amount'      => 0,
                                 'calls'       => 0,
                                 'duration'    => 0,
                                 'sort_weight' => -1,
                                 'phonenum'    => $phonenum,
                                };
      $sections{$phonenum}{amount} += $amount;  #subtotal
      $sections{$phonenum}{calls}++;
      $sections{$phonenum}{duration} += $detail->duration;

      my $desc = $detail->regionname;
      my $description = $desc;
      $description = substr($desc, 0, $maxlength). '...'
        if $format eq 'latex' && length($desc) > $maxlength;

      $lines{$phonenum}{$desc} ||= {
        description     => &{$escape}($description),
        #pkgpart         => $part_pkg->pkgpart,
        pkgnum          => '',
        ref             => '',
        amount          => 0,
        calls           => 0,
        duration        => 0,
        #unit_amount     => '',
        quantity        => '',
        product_code    => 'N/A',
        ext_description => [],
      };

      $lines{$phonenum}{$desc}{amount} += $amount;
      $lines{$phonenum}{$desc}{calls}++;
      $lines{$phonenum}{$desc}{duration} += $detail->duration;

      my $line = $usage_class{$detail->classnum}->classname;
      $sections{"$phonenum $line"} ||=
        { 'amount' => 0,
          'calls' => 0,
          'duration' => 0,
          'sort_weight' => $usage_class{$detail->classnum}->weight,
          'phonenum' => $phonenum,
          'header'  => [ @header ],
        };
      $sections{"$phonenum $line"}{amount} += $amount;  #subtotal
      $sections{"$phonenum $line"}{calls}++;
      $sections{"$phonenum $line"}{duration} += $detail->duration;

      $lines{"$phonenum $line"}{$desc} ||= {
        description     => &{$escape}($description),
        #pkgpart         => $part_pkg->pkgpart,
        pkgnum          => '',
        ref             => '',
        amount          => 0,
        calls           => 0,
        duration        => 0,
        #unit_amount     => '',
        quantity        => '',
        product_code    => 'N/A',
        ext_description => [],
      };

      $lines{"$phonenum $line"}{$desc}{amount} += $amount;
      $lines{"$phonenum $line"}{$desc}{calls}++;
      $lines{"$phonenum $line"}{$desc}{duration} += $detail->duration;
      push @{$lines{"$phonenum $line"}{$desc}{ext_description}},
           $detail->formatted('format' => $format);

    }
  }

  my %sectionmap = ();
  my $simple = new FS::usage_class { format => 'simple' }; #bleh
  foreach ( keys %sections ) {
    my @header = @{ $sections{$_}{header} || [] };
    my $usage_simple =
      new FS::usage_class { format => 'usage_'. (scalar(@header) || 6). 'col' };
    my $summary = $sections{$_}{sort_weight} < 0 ? 1 : 0;
    my $usage_class = $summary ? $simple : $usage_simple;
    my $ending = $summary ? ' usage charges' : '';
    my %gen_opt = ();
    unless ($summary) {
      $gen_opt{label} = [ map{ &{$escape}($_) } @header ];
    }
    $sectionmap{$_} = { 'description' => &{$escape}($_. $ending),
                        'amount'    => $sections{$_}{amount},    #subtotal
                        'calls'       => $sections{$_}{calls},
                        'duration'    => $sections{$_}{duration},
                        'summarized'  => '',
                        'tax_section' => '',
                        'phonenum'    => $sections{$_}{phonenum},
                        'sort_weight' => $sections{$_}{sort_weight},
                        'post_total'  => $summary, #inspire pagebreak
                        (
                          ( map { $_ => $usage_class->$_($format, %gen_opt) }
                            qw( description_generator
                                header_generator
                                total_generator
                                total_line_generator
                              )
                          )
                        ),
                      };
  }

  my @sections = sort { $a->{phonenum} cmp $b->{phonenum} ||
                        $a->{sort_weight} <=> $b->{sort_weight}
                      }
                 values %sectionmap;

  my @lines = ();
  foreach my $section ( keys %lines ) {
    foreach my $line ( keys %{$lines{$section}} ) {
      my $l = $lines{$section}{$line};
      $l->{section}     = $sectionmap{$section};
      $l->{amount}      = sprintf( "%.2f", $l->{amount} );
      #$l->{unit_amount} = sprintf( "%.2f", $l->{unit_amount} );
      push @lines, $l;
    }
  }

  if($conf->exists('phone_usage_class_summary')) {
      # this only works with Latex
      my @newlines;
      my @newsections;

      # after this, we'll have only two sections per DID:
      # Calls Summary and Calls Detail
      foreach my $section ( @sections ) {
	if($section->{'post_total'}) {
	    $section->{'description'} = 'Calls Summary: '.$section->{'phonenum'};
	    $section->{'total_line_generator'} = sub { '' };
	    $section->{'total_generator'} = sub { '' };
	    $section->{'header_generator'} = sub { '' };
	    $section->{'description_generator'} = '';
	    push @newsections, $section;
	    my %calls_detail = %$section;
	    $calls_detail{'post_total'} = '';
	    $calls_detail{'sort_weight'} = '';
	    $calls_detail{'description_generator'} = sub { '' };
	    $calls_detail{'header_generator'} = sub {
		return ' & Date/Time & Called Number & Duration & Price'
		    if $format eq 'latex';
		'';
	    };
	    $calls_detail{'description'} = 'Calls Detail: '
						    . $section->{'phonenum'};
	    push @newsections, \%calls_detail;
	}
      }

      # after this, each usage class is collapsed/summarized into a single
      # line under the Calls Summary section
      foreach my $newsection ( @newsections ) {
	if($newsection->{'post_total'}) { # this means Calls Summary
	    foreach my $section ( @sections ) {
		next unless ($section->{'phonenum'} eq $newsection->{'phonenum'}
				&& !$section->{'post_total'});
		my $newdesc = $section->{'description'};
		my $tn = $section->{'phonenum'};
		$newdesc =~ s/$tn//g;
		my $line = {  ext_description => [],
			      pkgnum => '',
			      ref => '',
			      quantity => '',
			      calls => $section->{'calls'},
			      section => $newsection,
			      duration => $section->{'duration'},
			      description => $newdesc,
			      amount => sprintf("%.2f",$section->{'amount'}),
			      product_code => 'N/A',
			    };
		push @newlines, $line;
	    }
	}
      }

      # after this, Calls Details is populated with all CDRs
      foreach my $newsection ( @newsections ) {
	if(!$newsection->{'post_total'}) { # this means Calls Details
	    foreach my $line ( @lines ) {
		next unless (scalar(@{$line->{'ext_description'}}) &&
			$line->{'section'}->{'phonenum'} eq $newsection->{'phonenum'}
			    );
		my @extdesc = @{$line->{'ext_description'}};
		my @newextdesc;
		foreach my $extdesc ( @extdesc ) {
		    $extdesc =~ s/scriptsize/normalsize/g if $format eq 'latex';
		    push @newextdesc, $extdesc;
		}
		$line->{'ext_description'} = \@newextdesc;
		$line->{'section'} = $newsection;
		push @newlines, $line;
	    }
	}
      }

      return(\@newsections, \@newlines);
  }

  return(\@sections, \@lines);

}

=sub _items_usage_class_summary OPTIONS

Returns a list of detail items summarizing the usage charges on this
invoice.  Each one will have 'amount', 'description' (the usage charge name),
and 'usage_classnum'.

OPTIONS can include 'escape' (a function to escape the descriptions).

=cut

sub _items_usage_class_summary {
  my $self = shift;
  my %opt = @_;

  my $escape = $opt{escape} || sub { $_[0] };
  my $money_char = $opt{money_char};
  my $invnum = $self->invnum;
  my @classes = qsearch({
      'table'     => 'usage_class',
      'select'    => 'classnum, classname, SUM(amount) AS amount,'.
                     ' COUNT(*) AS calls, SUM(duration) AS duration',
      'addl_from' => ' LEFT JOIN cust_bill_pkg_detail USING (classnum)' .
                     ' LEFT JOIN cust_bill_pkg USING (billpkgnum)',
      'extra_sql' => " WHERE cust_bill_pkg.invnum = $invnum".
                     ' GROUP BY classnum, classname, weight'.
                     ' HAVING (usage_class.disabled IS NULL OR SUM(amount) > 0)'.
                     ' ORDER BY weight ASC',
  });
  my @l;
  my $section = {
    description   => &{$escape}($self->mt('Usage Summary')),
    usage_section => 1,
    subtotal      => 0,
  };
  foreach my $class (@classes) {
    $section->{subtotal} += $class->get('amount');
    push @l, {
      'description'     => &{$escape}($class->classname),
      'amount'          => $money_char.sprintf('%.2f', $class->get('amount')),
      'quantity'        => $class->get('calls'),
      'duration'        => $class->get('duration'),
      'usage_classnum'  => $class->classnum,
      'section'         => $section,
    };
  }
  $section->{subtotal} = $money_char.sprintf('%.2f', $section->{subtotal});
  return @l;
}

=sub _items_previous()

  Returns an array of hashrefs, each hashref representing a line-item on
  the current bill for previous unpaid invoices.

  keys for each previous_item:
  - amount (see notes)
  - pkgnum
  - description
  - invnum
  - _date

  Payments and credits shown on this invoice may vary based on configuraiton.

  when conf flag previous_balance-payments_since is set:
    This method works backwards to rebuild the invoice as a snapshot in time.
    The invoice displayed will have the balances owed, and payments made,
    reflecting the state of the account at the time of invoice generation.

=cut

sub _items_previous {

  my $self = shift;

  # simple memoize
  if ($self->get('_items_previous')) {
    return sort { $a->{_date} <=> $b->{_date} }
         values %{ $self->get('_items_previous') };
  }

  # Gets the customer's current balance and outstanding invoices.
  my ($prev_balance, @open_invoices) = $self->previous;

  my %invoices = map {
    $_->invnum => $self->__items_previous_map_invoice($_)
  } @open_invoices;

  # Which credits and payments displayed on the bill will vary based on
  # conf flag previous_balance-payments_since.
  my @credits  = $self->_items_credits();
  my @payments = $self->_items_payments();


  if ($self->conf->exists('previous_balance-payments_since')) {
    # For each credit or payment, determine which invoices it was applied to.
    # Manipulate data displayed so the invoice displayed appears as a
    # snapshot in time... with previous balances and balance owed displayed
    # as they were at the time of invoice creation.

    my @credits_postbill = $self->_items_credits_postbill();
    my @payments_postbill = $self->_items_payments_postbill();

    my %pmnt_dupechk;
    my %cred_dupechk;

    # Each section below follows this pattern on a payment/credit
    #
    # - Dupe check, avoid adjusting for the same item twice
    # - If invoice being adjusted for isn't in our list, add it
    # - Adjust the invoice balance to refelct balnace without the
    #   credit or payment applied
    #

    # Working with payments displayed on this bill
    for my $pmt_hash (@payments) {
      my $pmt_obj = qsearchs('cust_pay', {paynum => $pmt_hash->{paynum}});
      for my $cust_bill_pay ($pmt_obj->cust_bill_pay) {
        next if exists $pmnt_dupechk{$cust_bill_pay->billpaynum};
        $pmnt_dupechk{$cust_bill_pay->billpaynum} = 1;

        my $invnum = $cust_bill_pay->invnum;

        $invoices{$invnum} = $self->__items_previous_get_invoice($invnum)
          unless exists $invoices{$invnum};

        $invoices{$invnum}->{amount} += $cust_bill_pay->amount;
      }
    }

    # Working with credits displayed on this bill
    for my $cred_hash (@credits) {
      my $cred_obj = qsearchs('cust_credit', {crednum => $cred_hash->{crednum}});
      for my $cust_credit_bill ($cred_obj->cust_credit_bill) {
        next if exists $cred_dupechk{$cust_credit_bill->creditbillnum};
        $cred_dupechk{$cust_credit_bill->creditbillnum} = 1;

        my $invnum = $cust_credit_bill->invnum;

        $invoices{$invnum} = $self->__items_previous_get_invoice($invnum)
          unless exists $invoices{$invnum};

        $invoices{$invnum}->{amount} += $cust_credit_bill->amount;
      }
    }

    # Working with both credits and payments which are not displayed
    # on this bill, but which have affected this bill's balances
    for my $postbill (@payments_postbill, @credits_postbill) {

      if ($postbill->{billpaynum}) {
        next if exists $pmnt_dupechk{$postbill->{billpaynum}};
        $pmnt_dupechk{$postbill->{billpaynum}} = 1;
      } elsif ($postbill->{creditbillnum}) {
        next if exists $cred_dupechk{$postbill->{creditbillnum}};
        $cred_dupechk{$postbill->{creditbillnum}} = 1;
      } else {
        die "Missing creditbillnum or billpaynum";
      }

      my $invnum = $postbill->{invnum};

      $invoices{$invnum} = $self->__items_previous_get_invoice($invnum)
        unless exists $invoices{$invnum};

      $invoices{$invnum}->{amount} += $postbill->{amount};
    }

    # Make sure current invoice doesn't appear in previous items
    delete $invoices{$self->invnum}
      if exists $invoices{$self->invnum};

  }

  # Make sure amount is formatted as a dollar string
  # (Formatting should happen on the template side, but is not?)
  $invoices{$_}->{amount} = sprintf('%.2f',$invoices{$_}->{amount})
    for keys %invoices;

  $self->set('_items_previous', \%invoices);
  return sort { $a->{_date} <=> $b->{_date} } values %invoices;

}

=sub _items_previous_total

  Return sum of amounts from all items returned by _items_previous
  Results will vary based on invoicing conf flags

=cut

sub _items_previous_total {
  my $self = shift;
  my $tot = 0;
  $tot += $_->{amount} for $self->_items_previous();
  return $tot;
}

sub __items_previous_get_invoice {
  # Helper function for _items_previous
  #
  # Read a record from cust_bill, return a hash of it's information
  my ($self, $invnum) = @_;
  die "Incorrect usage of __items_previous_get_invoice()" unless $invnum;

  my $cust_bill = qsearchs('cust_bill', {invnum => $invnum});
  return $self->__items_previous_map_invoice($cust_bill);
}

sub __items_previous_map_invoice {
  # Helper function for _items_previous
  #
  # Transform a cust_bill object into a simple hash reference of the type
  # required by _items_previous
  my ($self, $cust_bill) = @_;
  die "Incorrect usage of __items_previous_map_invoice" unless ref $cust_bill;

  my $date = $self->conf->exists('invoice_show_prior_due_date')
           ? 'due '.$cust_bill->due_date2str('short')
           : $self->time2str_local('short', $cust_bill->_date);

  return {
    invnum => $cust_bill->invnum,
    amount => $cust_bill->owed,
    pkgnum => 'N/A',
    _date  => $cust_bill->_date,
    description => join(' ',
      $self->mt('Previous Balance, Invoice #'),
      $cust_bill->invnum,
      "($date)"
    ),
  }
}

=sub _items_credits()

  Return array of hashrefs containing credits to be shown as line-items
  when rendering this bill.

  keys for each credit item:
  - crednum: id of payment
  - amount: payment amount
  - description: line item to be displayed on the bill

  This method has three ways it selects which credits to display on
  this bill:

  1) Default Case: No Conf flag for 'previous_balance-payments_since'

     Returns credits that have been applied to this bill only

  2) Case:
       Conf flag set for 'previous_balance-payments_since'

     List all credits that have been recorded during the time period
     between the timestamps of the last invoice and this invoice

  3) Case:
        Conf flag set for 'previous_balance-payments_since'
        $opt{'template'} eq 'statement'

    List all payments that have been recorded between the timestamps
    of the previous invoice and the following invoice.

     This is used to give the customer a receipt for a payment
     in the form of their last bill with the payment amended.

     I am concerned with this implementation, but leaving in place as is
     If this option is selected, while viewing an older bill, the old bill
     will show ALL future credits for future bills, but no charges for
     future bills.  Somebody could be misled into believing they have a
     large account credit when they don't.  Also, interrupts the chain of
     invoices as an account history... the customer could have two invoices
     in their fileing cabinet, for two different dates, both with a line item
     for the same duplicate credit.  The accounting is technically accurate,
     but somebody could easily become confused and think two credits were
     made, when really those two line items on two different bills represent
     only a single credit

=cut

sub _items_credits {

  my $self= shift;

  # Simple memoize
  return @{$self->get('_items_credits')} if $self->get('_items_credits');

  my %opt = @_;
  my $template = $opt{template} || $self->get('_template');
  my $trim_len = $opt{template} || $self->get('trim_len') || 40;

  my @return;
  my @cust_credit_objs;

  if ($self->conf->exists('previous_balance-payments_since')) {
    if ($template eq 'statement') {
      # Case 3 (see above)
      # Return credits timestamped between the previous and following bills

      my $previous_bill  = $self->previous_bill;
      my $following_bill = $self->following_bill;

      my $date_start = ref $previous_bill  ? $previous_bill->_date  : 0;
      my $date_end   = ref $following_bill ? $following_bill->_date : undef;

      my %query = (
        table => 'cust_credit',
        hashref => {
          custnum => $self->custnum,
          _date => { op => '>=', value => $date_start },
        },
      );
      $query{extra_sql} = " AND _date <= $date_end " if $date_end;

      @cust_credit_objs = qsearch(\%query);

    } else {
      # Case 2 (see above)
      # Return credits timestamps between this and the previous bills

      my $date_start = 0;
      my $date_end = $self->_date;

      my $previous_bill = $self->previous_bill;
      if (ref $previous_bill) {
        $date_start = $previous_bill->_date;
      }

      @cust_credit_objs = qsearch({
        table => 'cust_credit',
        hashref => {
          custnum => $self->custnum,
          _date => {op => '>=', value => $date_start},
        },
        extra_sql => " AND _date <= $date_end ",
      });
    }

  } else {
    # Case 1 (see above)
    # Return only credits that have been applied to this bill

    @cust_credit_objs = $self->cust_credited;

  }

  # Translate objects into hashrefs
  foreach my $obj ( @cust_credit_objs ) {
    my $cust_credit = $obj->isa('FS::cust_credit') ? $obj : $obj->cust_credit;
    my %r_obj = (
      amount       => sprintf('%.2f',$cust_credit->amount),
      crednum      => $cust_credit->crednum,
      _date        => $cust_credit->_date,
      creditreason => $cust_credit->reason,
    );

    my $reason = substr($cust_credit->reason, 0, $trim_len);
    $reason .= '...' if length($reason) < length($cust_credit->reason);
    $reason = "($reason)" if $reason;

    $r_obj{description} = join(' ',
      $self->mt('Credit applied'),
      $self->time2str_local('short', $cust_credit->_date),
      $reason,
    );

    push @return, \%r_obj;
  }
  $self->set('_items_credits',\@return);
  @return;
}

=sub _items_credits_total

  Return the total of al items from _items_credits
  Will vary based on invoice display conf flag

=cut

sub _items_credits_total {
  my $self = shift;
  my $tot = 0;
  $tot += $_->{amount} for $self->_items_credits();
  return $tot;
}



=sub _items_credits_postbill()

  Returns an array of hashrefs for credits where
  - Credit issued after this invoice
  - Credit applied to an invoice before this invoice

  Returned hashrefs are of the format returned by _items_credits()

=cut

sub _items_credits_postbill {
  my $self = shift;

  my @cust_credit_bill = qsearch({
    table   => 'cust_credit_bill',
    select  => join(', ',qw(
      cust_credit_bill.creditbillnum
      cust_credit_bill._date
      cust_credit_bill.invnum
      cust_credit_bill.amount
    )),
    addl_from => ' LEFT JOIN cust_credit'.
                 ' ON (cust_credit_bill.crednum = cust_credit.crednum) ',
    extra_sql => ' WHERE cust_credit.custnum     = '.$self->custnum.
                 ' AND   cust_credit_bill._date  > '.$self->_date.
                 ' AND   cust_credit_bill.invnum < '.$self->invnum.' ',
#! did not investigate why hashref doesn't work for this join query
#    hashref => {
#      'cust_credit.custnum'     => {op => '=', value => $self->custnum},
#      'cust_credit_bill._date'  => {op => '>', value => $self->_date},
#      'cust_credit_bill.invnum' => {op => '<', value => $self->invnum},
#    },
  });

  return map {{
    _date         => $_->_date,
    invnum        => $_->invnum,
    amount        => $_->amount,
    creditbillnum => $_->creditbillnum,
  }} @cust_credit_bill;
}

=sub _items_payments_postbill()

  Returns an array of hashrefs for payments where
  - Payment occured after this invoice
  - Payment applied to an invoice before this invoice

  Returned hashrefs are of the format returned by _items_payments()

=cut

sub _items_payments_postbill {
  my $self = shift;

  my @cust_bill_pay = qsearch({
    table    => 'cust_bill_pay',
    select => join(', ',qw(
      cust_bill_pay.billpaynum
      cust_bill_pay._date
      cust_bill_pay.invnum
      cust_bill_pay.amount
    )),
    addl_from => ' LEFT JOIN cust_bill'.
                 ' ON (cust_bill_pay.invnum = cust_bill.invnum) ',
    extra_sql => ' WHERE cust_bill.custnum     = '.$self->custnum.
                 ' AND   cust_bill_pay._date   > '.$self->_date.
                 ' AND   cust_bill_pay.invnum  < '.$self->invnum.' ',
  });

  return map {{
    _date      => $_->_date,
    invnum     => $_->invnum,
    amount     => $_->amount,
    billpaynum => $_->billpaynum,
  }} @cust_bill_pay;
}

=sub _items_payments()

  Return array of hashrefs containing payments to be shown as line-items
  when rendering this bill.

  keys for each payment item:
  - paynum: id of payment
  - amount: payment amount
  - description: line item to be displayed on the bill

  This method has three ways it selects which payments to display on
  this bill:

  1) Default Case: No Conf flag for 'previous_balance-payments_since'

     Returns payments that have been applied to this bill only

  2) Case:
       Conf flag set for 'previous_balance-payments_since'

     List all payments that have been recorded between the timestamps
     of the previous invoice and this invoice

  3) Case:
        Conf flag set for 'previous_balance-payments_since'
        $opt{'template'} eq 'statement'

     List all payments that have been recorded between the timestamps
     of the previous invoice and the following invoice.

     I am concerned with this implementation, but leaving in place as is
     If this option is selected, while viewing an older bill, the old bill
     will show ALL future payments for future bills, but no charges for
     future bills.  Somebody could be misled into believing they have a
     large account credit when they don't.  Also, interrupts the chain of
     invoices as an account history... the customer could have two invoices
     in their fileing cabinet, for two different dates, both with a line item
     for the same duplicate payment.  The accounting is technically accurate,
     but somebody could easily become confused and think two payments were
     made, when really those two line items on two different bills represent
     only a single payment.

=cut

sub _items_payments {

  my $self = shift;

  # Simple memoize
  return @{$self->get('_items_payments')} if $self->get('_items_payments');

  my %opt = @_;
  my $template = $opt{template} || $self->get('_template');

  my @return;
  my @cust_pay_objs;

  my $c_invoice_payment_details = $self->conf->exists('invoice_payment_details');

  if ($self->conf->exists('previous_balance-payments_since')) {
    if ($template eq 'statement') {
print "\nCASE 3\n";
      # Case 3 (see above)
      # Return payments timestamped between the previous and following bills

      my $previous_bill  = $self->previous_bill;
      my $following_bill = $self->following_bill;

      my $date_start = ref $previous_bill  ? $previous_bill->_date  : 0;
      my $date_end   = ref $following_bill ? $following_bill->_date : undef;

      my %query = (
        table => 'cust_pay',
        hashref => {
          custnum => $self->custnum,
          _date => { op => '>=', value => $date_start },
        },
      );
      $query{extra_sql} = " AND _date <= $date_end " if $date_end;

      @cust_pay_objs = qsearch(\%query);

    } else {
      # Case 2 (see above)
      # Return payments timestamped between this and the previous bill
print "\nCASE 2\n";
      my $date_start = 0;
      my $date_end = $self->_date;

      my $previous_bill = $self->previous_bill;
      if (ref $previous_bill) {
        $date_start = $previous_bill->_date;
      }

      @cust_pay_objs = qsearch({
        table => 'cust_pay',
        hashref => {
          custnum => $self->custnum,
          _date => {op => '>=', value => $date_start},
        },
        extra_sql => " AND _date <= $date_end ",
      });
    }

  } else {
    # Case 1 (see above)
    # Return payments applied only to this bill

    @cust_pay_objs = $self->cust_bill_pay;

  }

  $self->set(
    '_items_payments',
    [ $self->__items_payments_make_hashref(@cust_pay_objs) ]
  );
  return @{ $self->get('_items_payments') };
}

=sub _items_payments_total

  Return a total of all records returned by _items_payments
  Results vary based on invoicing conf flags

=cut

sub _items_payments_total {
  my $self = shift;
  my $tot = 0;
  $tot += $_->{amount} for $self->_items_payments();
  return $tot;
}

sub __items_payments_make_hashref {
  # Transform a FS::cust_pay object into a simple hashref for invoice
  my ($self, @cust_pay_objs) = @_;
  my $c_invoice_payment_details = $self->conf->exists('invoice_payment_details');
  my @return;

  for my $obj (@cust_pay_objs) {

    # In case we're passed FS::cust_bill_pay (or something else?)
    # Below, we use $obj to render amount rather than $cust_apy.
    #   If we were passed cust_bill_pay objs, then:
    #   $obj->amount represents the amount applied to THIS invoice
    #   $cust_pay->amount represents the total payment, which may have
    #       been applied accross several invoices.
    # If we were passed cust_bill_pay objects, then the conf flag
    # previous_balance-payments_since is NOT set, so we should not
    # present any payments not applied to this invoice.
    my $cust_pay = $obj->isa('FS::cust_pay') ? $obj : $obj->cust_pay;

    my %r_obj = (
      _date   => $cust_pay->_date,
      amount  => sprintf("%.2f", $obj->amount),
      paynum  => $cust_pay->paynum,
      payinfo => $cust_pay->payby_payinfo_pretty(),
      description => join(' ',
        $self->mt('Payment received'),
        $self->time2str_local('short', $cust_pay->_date),
      ),
    );

    if ($c_invoice_payment_details) {
      $r_obj{description} = join(' ',
        $r_obj{description},
        $self->mt('via'),
        $cust_pay->payby_payinfo_pretty($self->cust_main->locale),
      );
    }

    push @return, \%r_obj;
  }
  return @return;
}

=sub _items_total()

  Generate the line-items to be shown on the bill in the "Totals" section

  Returns a list of hashrefs, each with the keys:
  - total_item: description field
  - total_amount: dollar-formatted number amount

  Information presented by this method varies based on Conf

  Conf previous_balance-payments_due
  - default, flag not set
      Only transactions that were applied to this bill bill be
      displayed and calculated intothe total.  If items exist in
      the past-due section, those items will disappear from this
      invoice if they have been paid off.

  - previous_balance-payments_due flag is set
      Transactions occuring after the timestsamp of this
      invoice are not reflected on invoice line items

      Only payments/credits applied between the previous invoice
      and this one are displayed and calculated into the total

  - previous_balance-payments_due && $opt{template} eq 'statement'
      Same as above, except payments/credits occuring before the date
      of the following invoice are also displayed and calculated into
      the total

  Conf previous_balance-exclude_from_total
  - default, flag not set
      The "Totals" section contains a single line item.
      The dollar amount of this line items is a sum of old and new charges
  - previous_balance-exclude_from_total flag is set
      The "Totals" section contains two line items.
      One for previous balance, one for new charges
  !NOTE: Avent virtualization flag 'disable_previous_balance' can
      override the global conf flag previous_balance-exclude_from_total

  Conf invoice_show_prior_due_date
  - default, flag not set
    Total line item in the "Totals" section does not mention due date
  - invoice_show_prior_due_date flag is set
    Total line item in the "Totals" section includes either the due
    date of the invoice, or the specified invoice terms
    ? Not sure why this is called "Prior" due date, since we seem to be
      displaying THIS due date...
=cut

sub _items_total {
  my $self = shift;
  my $conf = $self->conf;

  my $c_multi_line_total = 0;
  $c_multi_line_total    = 1
    if $conf->exists('previous_balance-exclude_from_total')
    && $self->enable_previous();

  my @line_items;
  my $invoice_charges  = $self->charged();

  # _items_previous() is aware of conf flags
  my $previous_balance = 0;
  $previous_balance += $_->{amount} for $self->_items_previous();

  my $total_charges;
  my $total_descr;

  if ( $previous_balance && $c_multi_line_total ) {
    # previous balance, new charges on separate lines

    push @line_items, {
      total_amount => sprintf('%.2f',$previous_balance),
      total_item   => $self->mt(
        $conf->config('previous_balance-text') || 'Previous Balance'
      ),
    };

    $total_charges = $invoice_charges;
    $total_descr   = $self->mt(
      $conf->config('previous_balance-text-total_new_charges')
      || 'Total New Charges'
    );

  } else {
    # previous balance and new charges combined into a single total line
    $total_charges = $invoice_charges + $previous_balance;
    $total_descr = $self->mt('Total Charges');
  }

  if ( $conf->exists('invoice_show_prior_due_date') ) {
    # then the due date should be shown with Total New Charges,
    # and should NOT be shown with the Balance Due message.

    if ( $self->due_date ) {
      $total_descr = join(' ',
        $total_descr,
        '-',
        $self->mt('Please pay by'),
        $self->due_date2str('short')
      );
    } elsif ( $self->terms ) {
      $total_descr = join(' ',
        $total_descr,
        '-',
        $self->mt($self->terms)
      );
    }
  }

  push @line_items, {
    total_amount => sprintf('%.2f', $total_charges),
    total_item   => $total_descr,
  };

  return @line_items;
}

=item _items_aging_balances

  Returns an array of aged balance amounts from a given epoch timestamp.

  The time of day is ignored for this calculation, so that slight differences
  on the generation time of an invoice doesn't determine which column an
  aged balance falls into.

  Will not include any balances dated after the given timestamp in
  the calculated totals

  usage:
  @aged_balances = $b->_items_aging_balances( $b->_date )

  @aged_balances = (
    under30d,
    30d-60d,
    60d-90d,
    over90d
  )

=cut

sub _items_aging_balances {
  my ($self, $basetime) = @_;
  die "Incorrect usage of _items_aging_balances()" unless ref $self;

  $basetime = $self->_date unless $basetime;
  my @aging_balances = (0, 0, 0, 0);
  my @open_invoices = $self->_items_previous();
  my $d30 = 2592000; # 60 * 60 * 24 * 30,
  my $d60 = 5184000; # 60 * 60 * 24 * 60,
  my $d90 = 7776000; # 60 * 60 * 24 * 90

  # Move the clock back on our given day to 12:00:01 AM
  my $dt_basetime = DateTime->from_epoch(epoch => $basetime);
  my $dt_12am = DateTime->new(
    year   => $dt_basetime->year,
    month  => $dt_basetime->month,
    day    => $dt_basetime->day,
    hour   => 0,
    minute => 0,
    second => 1,
  )->epoch();

  # set our epoch breakpoints
  $_ = $dt_12am - $_ for $d30, $d60, $d90;

  # grep the aged balances
  for my $oinv (@open_invoices) {
    if ($oinv->{_date} <= $basetime && $oinv->{_date} > $d30) {
      # If post invoice dated less than 30days ago
      $aging_balances[0] += $oinv->{amount};
    } elsif ($oinv->{_date} <= $d30 && $oinv->{_date} > $d60) {
      # If past invoice dated between 30-60 days ago
      $aging_balances[1] += $oinv->{amount};
    } elsif ($oinv->{_date} <= $d60 && $oinv->{_date} > $d90) {
      # If past invoice dated between 60-90 days ago
      $aging_balances[2] += $oinv->{amount};
    } else {
      # If past invoice dated 90+ days ago
      $aging_balances[3] += $oinv->{amount};
    }
  }

  return map{ sprintf('%.2f',$_) } @aging_balances;
}

=item call_details [ OPTION => VALUE ... ]

Returns an array of CSV strings representing the call details for this invoice
The only option available is the boolean prepend_billed_number

=cut

sub call_details {
  my ($self, %opt) = @_;

  my $format_function = sub { shift };

  if ($opt{prepend_billed_number}) {
    $format_function = sub {
      my $detail = shift;
      my $row = shift;

      $row->amount ? $row->phonenum. ",". $detail : '"Billed number",'. $detail;

    };
  }

  my @details = map { $_->details( 'format_function' => $format_function,
                                   'escape_function' => sub{ return() },
                                 )
                    }
                  grep { $_->pkgnum }
                  $self->cust_bill_pkg;
  my $header = $details[0];
  ( $header, grep { $_ ne $header } @details );
}

=item cust_pay_batch

Returns all L<FS::cust_pay_batch> records linked to this invoice. Deprecated,
will be removed.

=cut

sub cust_pay_batch {
  carp "FS::cust_bill->cust_pay_batch is deprecated";
  my $self = shift;
  qsearch('cust_pay_batch', { 'invnum' => $self->invnum });
}

=back

=head1 SUBROUTINES

=over 4

=item process_reprint

=cut

sub process_reprint {
  process_re_X('print', @_);
}

=item process_reemail

=cut

sub process_reemail {
  process_re_X('email', @_);
}

=item process_refax

=cut

sub process_refax {
  process_re_X('fax', @_);
}

=item process_reftp

=cut

sub process_reftp {
  process_re_X('ftp', @_);
}

=item respool

=cut

sub process_respool {
  process_re_X('spool', @_);
}

use Data::Dumper;
sub process_re_X {
  my( $method, $job ) = ( shift, shift );
  warn "$me process_re_X $method for job $job\n" if $DEBUG;

  my $param = shift;
  warn Dumper($param) if $DEBUG;

  re_X(
    $method,
    $job,
    %$param,
  );

}

# this is called from search/cust_bill.html and given all its search
# parameters, so it needs to perform the same search.

sub re_X {
  # spool_invoice ftp_invoice fax_invoice print_invoice
  my($method, $job, %param ) = @_;
  if ( $DEBUG ) {
    warn "re_X $method for job $job with param:\n".
         join( '', map { "  $_ => ". $param{$_}. "\n" } keys %param );
  }

  #some false laziness w/search/cust_bill.html
  $param{'order_by'} = 'cust_bill._date';

  my $query = FS::cust_bill->search(\%param);
  delete $query->{'count_query'};
  delete $query->{'count_addl'};

  $query->{debug} = 1; # was in here before, is obviously useful

  my @cust_bill = qsearch( $query );

  $method .= '_invoice' unless $method eq 'email' || $method eq 'print';

  warn " $me re_X $method: ". scalar(@cust_bill). " invoices found\n"
    if $DEBUG;

  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
  foreach my $cust_bill ( @cust_bill ) {
    $cust_bill->$method();

    if ( $job ) { #progressbar foo
      $num++;
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $num / scalar(@cust_bill) )
        );
        die $error if $error;
        $last = time;
      }
    }

  }

}

sub API_getinfo {
  my $self = shift;
  +{ ( map { $_=>$self->$_ } $self->fields ),
     'owed' => $self->owed,
     #XXX last payment applied date
   };
}

=back

=head1 CLASS METHODS

=over 4

=item owed_sql

Returns an SQL fragment to retreive the amount owed (charged minus credited and paid).

=cut

sub owed_sql {
  my ($class, $start, $end) = @_;
  'charged - '.
    $class->paid_sql($start, $end). ' - '.
    $class->credited_sql($start, $end);
}

=item net_sql

Returns an SQL fragment to retreive the net amount (charged minus credited).

=cut

sub net_sql {
  my ($class, $start, $end) = @_;
  'charged - '. $class->credited_sql($start, $end);
}

=item paid_sql

Returns an SQL fragment to retreive the amount paid against this invoice.

=cut

sub paid_sql {
  my ($class, $start, $end) = @_;
  $start &&= "AND cust_bill_pay._date <= $start";
  $end   &&= "AND cust_bill_pay._date > $end";
  $start = '' unless defined($start);
  $end   = '' unless defined($end);
  "( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
       WHERE cust_bill.invnum = cust_bill_pay.invnum $start $end  )";
}

=item credited_sql

Returns an SQL fragment to retreive the amount credited against this invoice.

=cut

sub credited_sql {
  my ($class, $start, $end) = @_;
  $start &&= "AND cust_credit_bill._date <= $start";
  $end   &&= "AND cust_credit_bill._date >  $end";
  $start = '' unless defined($start);
  $end   = '' unless defined($end);
  "( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
       WHERE cust_bill.invnum = cust_credit_bill.invnum $start $end  )";
}

=item due_date_sql

Returns an SQL fragment to retrieve the due date of an invoice.
Currently only supported on PostgreSQL.

=cut

sub due_date_sql {
  die "don't use: doesn't account for agent-specific invoice_default_terms";

  #we're passed a $conf but not a specific customer (that's in the query), so
  # to make this work we'd need an agentnum-aware "condition_sql_conf" like
  # "condition_sql_option" that retreives a conf value with SQL in an agent-
  # aware fashion

  my $conf = new FS::Conf;
'COALESCE(
  SUBSTRING(
    COALESCE(
      cust_bill.invoice_terms,
      cust_main.invoice_terms,
      \''.($conf->config('invoice_default_terms') || '').'\'
    ), E\'Net (\\\\d+)\'
  )::INTEGER, 0
) * 86400 + cust_bill._date'
}

=back

=head1 BUGS

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill_pay>, L<FS::cust_pay>,
L<FS::cust_bill_pkg>, L<FS::cust_bill_credit>, schema.html from the base
documentation.

=cut

1;
