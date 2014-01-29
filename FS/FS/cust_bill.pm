package FS::cust_bill;

use strict;
use vars qw( @ISA $DEBUG $me 
             $money_char );
             # but NOT $conf
use vars qw( $invoice_lines @buf ); #yuck
use Fcntl qw(:flock); #for spool_csv
use Cwd;
use List::Util qw(min max sum);
use Date::Format;
use Date::Language;
use Text::Template 1.20;
use File::Temp 0.14;
use String::ShellQuote;
use HTML::Entities;
use Locale::Country;
use Storable qw( freeze thaw );
use GD::Barcode;
use FS::UID qw( datasrc );
use FS::Misc qw( send_email send_fax generate_ps generate_pdf do_print );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_main_Mixin;
use FS::cust_main;
use FS::cust_statement;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_detail;
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_pkg;
use FS::cust_credit_bill;
use FS::pay_batch;
use FS::cust_pay_batch;
use FS::cust_bill_event;
use FS::cust_event;
use FS::part_pkg;
use FS::cust_bill_pay;
use FS::cust_bill_pay_batch;
use FS::part_bill_event;
use FS::payby;
use FS::bill_batch;
use FS::cust_bill_batch;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::discount_plan;
use FS::L10N;

@ISA = qw( FS::cust_main_Mixin FS::Record );

$DEBUG = 0;
$me = '[FS::cust_bill]';

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  my $conf = new FS::Conf; #global
  $money_char       = $conf->config('money_char')       || '$';  
} );

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
  @lines = $cust_bill->print_text $time;

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

Customer info at invoice generation time

=over 4

=item previous_balance

=item billing_balance

=back

Deprecated

=over 4

=item printed - deprecated

=back

Specific use cases

=over 4

=item closed - books closed flag, empty or `Y'

=item statementnum - invoice aggregation (see L<FS::cust_statement>)

=item agent_invid - legacy invoice number

=item promised_date - customer promised payment date, for collection

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice.  To add the invoice to the database, see L<"insert">.
Invoices are normally created by calling the bill method of a customer object
(see L<FS::cust_main>).

=cut

sub table { 'cust_bill'; }

sub cust_linked { $_[0]->cust_main_custnum; } 
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

=item delete

This method now works but you probably shouldn't use it.  Instead, apply a
credit against the invoice.

Using this method to delete invoices outright is really, really bad.  There
would be no record you ever posted this invoice, and there are no check to
make sure charged = 0 or that there are no associated cust_bill_pkg records.

Really, don't use it.

=cut

sub delete {
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
    cust_bill_event
    cust_event
    cust_credit_bill
    cust_bill_pay
    cust_credit_bill
    cust_pay_batch
    cust_bill_pay_batch
    cust_bill_pkg
    cust_bill_batch
  )) {

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
  my $conf = $self->conf;
  if ( $conf->exists('cust_bill-default_agent_invid') && $self->agent_invid ){
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

=item previous

Returns a list consisting of the total previous balance for this customer, 
followed by the previous outstanding invoices (as FS::cust_bill objects also).

=cut

sub previous {
  my $self = shift;
  my $total = 0;
  my @cust_bill = sort { $a->_date <=> $b->_date }
    grep { $_->owed != 0 }
      qsearch( 'cust_bill', { 'custnum'  => $self->custnum,
                              #'_date'   => { op=>'<', value=>$self->_date },
                              'invnum'   => { op=>'<', value=>$self->invnum },
                            } ) 
  ;
  foreach ( @cust_bill ) { $total += $_->owed; }
  $total, @cust_bill;
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
      'order_by' => 'ORDER BY billpkgnum',
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

=item cust_bill_event

Returns the completed invoice events (deprecated, old-style events - see L<FS::cust_bill_event>) for this invoice.

=cut

sub cust_bill_event {
  my $self = shift;
  qsearch( 'cust_bill_event', { 'invnum' => $self->invnum } );
}

=item num_cust_bill_event

Returns the number of completed invoice events (deprecated, old-style events - see L<FS::cust_bill_event>) for this invoice.

=cut

sub num_cust_bill_event {
  my $self = shift;
  my $sql =
    "SELECT COUNT(*) FROM cust_bill_event WHERE invnum = ?";
  my $sth = dbh->prepare($sql) or die  dbh->errstr. " preparing $sql"; 
  $sth->execute($self->invnum) or die $sth->errstr. " executing $sql";
  $sth->fetchrow_arrayref->[0];
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

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
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

=item cust_credit

Depreciated.  See the cust_credited method.

 #Returns a list consisting of the total previous credited (see
 #L<FS::cust_credit>) and unapplied for this customer, followed by the previous
 #outstanding credits (FS::cust_credit objects).

=cut

sub cust_credit {
  use Carp;
  croak "FS::cust_bill->cust_credit depreciated; see ".
        "FS::cust_bill->cust_credit_bill";
  #my $self = shift;
  #my $total = 0;
  #my @cust_credit = sort { $a->_date <=> $b->_date }
  #  grep { $_->credited != 0 && $_->_date < $self->_date }
  #    qsearch('cust_credit', { 'custnum' => $self->custnum } )
  #;
  #foreach (@cust_credit) { $total += $_->credited; }
  #$total, @cust_credit;
}

=item cust_pay

Depreciated.  See the cust_bill_pay method.

#Returns all payments (see L<FS::cust_pay>) for this invoice.

=cut

sub cust_pay {
  use Carp;
  croak "FS::cust_bill->cust_pay depreciated; see FS::cust_bill->cust_bill_pay";
  #my $self = shift;
  #sort { $a->_date <=> $b->_date }
  #  qsearch( 'cust_pay', { 'invnum' => $self->invnum } )
  #;
}

sub cust_pay_batch {
  my $self = shift;
  qsearch('cust_pay_batch', { 'invnum' => $self->invnum } );
}

sub cust_bill_pay_batch {
  my $self = shift;
  qsearch('cust_bill_pay_batch', { 'invnum' => $self->invnum } );
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

  my @payments = grep { $_->unapplied > 0 } $self->cust_main->cust_pay;
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

=item generate_email OPTION => VALUE ...

Options:

=over 4

=item from

sender address, required

=item tempate

alternate template name, optional

=item print_text

text attachment arrayref, optional

=item subject

email subject, optional

=item notice_name

notice name instead of "Invoice", optional

=back

Returns an argument list to be passed to L<FS::Misc::send_email>.

=cut

use MIME::Entity;

sub generate_email {

  my $self = shift;
  my %args = @_;
  my $conf = $self->conf;

  my $me = '[FS::cust_bill::generate_email]';

  my %return = (
    'from'      => $args{'from'},
    'subject'   => (($args{'subject'}) ? $args{'subject'} : 'Invoice'),
  );

  my %opt = (
    'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
    'template'      => $args{'template'},
    'notice_name'   => ( $args{'notice_name'} || 'Invoice' ),
    'no_coupon'     => $args{'no_coupon'},
  );

  my $cust_main = $self->cust_main;

  if (ref($args{'to'}) eq 'ARRAY') {
    $return{'to'} = $args{'to'};
  } else {
    $return{'to'} = [ grep { $_ !~ /^(POST|FAX)$/ }
                           $cust_main->invoicing_list
                    ];
  }

  if ( $conf->exists('invoice_html') ) {

    warn "$me creating HTML/text multipart message"
      if $DEBUG;

    $return{'nobody'} = 1;

    my $alternative = build MIME::Entity
      'Type'        => 'multipart/alternative',
      #'Encoding'    => '7bit',
      'Disposition' => 'inline'
    ;

    my $data;
    if ( $conf->exists('invoice_email_pdf')
         and scalar($conf->config('invoice_email_pdf_note')) ) {

      warn "$me using 'invoice_email_pdf_note' in multipart message"
        if $DEBUG;
      $data = [ map { $_ . "\n" }
                    $conf->config('invoice_email_pdf_note')
              ];

    } else {

      warn "$me not using 'invoice_email_pdf_note' in multipart message"
        if $DEBUG;
      if ( ref($args{'print_text'}) eq 'ARRAY' ) {
        $data = $args{'print_text'};
      } else {
        $data = [ $self->print_text(\%opt) ];
      }

    }

    $alternative->attach(
      'Type'        => 'text/plain',
      'Encoding'    => 'quoted-printable',
      #'Encoding'    => '7bit',
      'Data'        => $data,
      'Disposition' => 'inline',
    );


    my $htmldata;
    my $image = '';
    my $barcode = '';
    if ( $conf->exists('invoice_email_pdf')
         and scalar($conf->config('invoice_email_pdf_note')) ) {

      $htmldata = join('<BR>', $conf->config('invoice_email_pdf_note') );

    } else {

      $args{'from'} =~ /\@([\w\.\-]+)/;
      my $from = $1 || 'example.com';
      my $content_id = join('.', rand()*(2**32), $$, time). "\@$from";

      my $logo;
      my $agentnum = $cust_main->agentnum;
      if ( defined($args{'template'}) && length($args{'template'})
           && $conf->exists( 'logo_'. $args{'template'}. '.png', $agentnum )
         )
      {
        $logo = 'logo_'. $args{'template'}. '.png';
      } else {
        $logo = "logo.png";
      }
      my $image_data = $conf->config_binary( $logo, $agentnum);

      $image = build MIME::Entity
        'Type'       => 'image/png',
        'Encoding'   => 'base64',
        'Data'       => $image_data,
        'Filename'   => 'logo.png',
        'Content-ID' => "<$content_id>",
      ;
   
      if ($conf->exists('invoice-barcode')) {
        my $barcode_content_id = join('.', rand()*(2**32), $$, time). "\@$from";
        $barcode = build MIME::Entity
          'Type'       => 'image/png',
          'Encoding'   => 'base64',
          'Data'       => $self->invoice_barcode(0),
          'Filename'   => 'barcode.png',
          'Content-ID' => "<$barcode_content_id>",
        ;
        $opt{'barcode_cid'} = $barcode_content_id;
      }

      $htmldata = $self->print_html({ 'cid'=>$content_id, %opt });
    }

    $alternative->attach(
      'Type'        => 'text/html',
      'Encoding'    => 'quoted-printable',
      'Data'        => [ '<html>',
                         '  <head>',
                         '    <title>',
                         '      '. encode_entities($return{'subject'}), 
                         '    </title>',
                         '  </head>',
                         '  <body bgcolor="#e8e8e8">',
                         $htmldata,
                         '  </body>',
                         '</html>',
                       ],
      'Disposition' => 'inline',
      #'Filename'    => 'invoice.pdf',
    );


    my @otherparts = ();
    if ( $cust_main->email_csv_cdr ) {

      push @otherparts, build MIME::Entity
        'Type'        => 'text/csv',
        'Encoding'    => '7bit',
        'Data'        => [ map { "$_\n" }
                             $self->call_details('prepend_billed_number' => 1)
                         ],
        'Disposition' => 'attachment',
        'Filename'    => 'usage-'. $self->invnum. '.csv',
      ;

    }

    if ( $conf->exists('invoice_email_pdf') ) {

      #attaching pdf too:
      # multipart/mixed
      #   multipart/related
      #     multipart/alternative
      #       text/plain
      #       text/html
      #     image/png
      #   application/pdf

      my $related = build MIME::Entity 'Type'     => 'multipart/related',
                                       'Encoding' => '7bit';

      #false laziness w/Misc::send_email
      $related->head->replace('Content-type',
        $related->mime_type.
        '; boundary="'. $related->head->multipart_boundary. '"'.
        '; type=multipart/alternative'
      );

      $related->add_part($alternative);

      $related->add_part($image) if $image;

      my $pdf = build MIME::Entity $self->mimebuild_pdf(\%opt);

      $return{'mimeparts'} = [ $related, $pdf, @otherparts ];

    } else {

      #no other attachment:
      # multipart/related
      #   multipart/alternative
      #     text/plain
      #     text/html
      #   image/png

      $return{'content-type'} = 'multipart/related';
      if ($conf->exists('invoice-barcode') && $barcode) {
        $return{'mimeparts'} = [ $alternative, $image, $barcode, @otherparts ];
      } else {
        $return{'mimeparts'} = [ $alternative, $image, @otherparts ];
      }
      $return{'type'} = 'multipart/alternative'; #Content-Type of first part...
      #$return{'disposition'} = 'inline';

    }
  
  } else {

    if ( $conf->exists('invoice_email_pdf') ) {
      warn "$me creating PDF attachment"
        if $DEBUG;

      #mime parts arguments a la MIME::Entity->build().
      $return{'mimeparts'} = [
        { $self->mimebuild_pdf(\%opt) }
      ];
    }
  
    if ( $conf->exists('invoice_email_pdf')
         and scalar($conf->config('invoice_email_pdf_note')) ) {

      warn "$me using 'invoice_email_pdf_note'"
        if $DEBUG;
      $return{'body'} = [ map { $_ . "\n" }
                              $conf->config('invoice_email_pdf_note')
                        ];

    } else {

      warn "$me not using 'invoice_email_pdf_note'"
        if $DEBUG;
      if ( ref($args{'print_text'}) eq 'ARRAY' ) {
        $return{'body'} = $args{'print_text'};
      } else {
        $return{'body'} = [ $self->print_text(\%opt) ];
      }

    }

  }

  %return;

}

=item mimebuild_pdf

Returns a list suitable for passing to MIME::Entity->build(), representing
this invoice as PDF attachment.

=cut

sub mimebuild_pdf {
  my $self = shift;
  (
    'Type'        => 'application/pdf',
    'Encoding'    => 'base64',
    'Data'        => [ $self->print_pdf(@_) ],
    'Disposition' => 'attachment',
    'Filename'    => 'invoice-'. $self->invnum. '.pdf',
  );
}

=item send HASHREF | [ TEMPLATE [ , AGENTNUM [ , INVOICE_FROM [ , AMOUNT ] ] ] ]

Sends this invoice to the destinations configured for this customer: sends
email, prints and/or faxes.  See L<FS::cust_main_invoice>.

Options can be passed as a hashref (recommended) or as a list of up to 
four values for templatename, agentnum, invoice_from and amount.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<agentnum>, if specified, means that this invoice will only be sent for customers
of the specified agent or agent(s).  AGENTNUM can be a scalar agentnum (for a
single agent) or an arrayref of agentnums.

I<invoice_from>, if specified, overrides the default email invoice From: address.

I<amount>, if specified, only sends the invoice if the total amount owed on this
invoice and all older invoices is greater than the specified amount.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub queueable_send {
  my %opt = @_;

  my $self = qsearchs('cust_bill', { 'invnum' => $opt{invnum} } )
    or die "invalid invoice number: " . $opt{invnum};

  my @args = ( $opt{template}, $opt{agentnum} );
  push @args, $opt{invoice_from}
    if exists($opt{invoice_from}) && $opt{invoice_from};

  my $error = $self->send( @args );
  die $error if $error;

}

sub send {
  my $self = shift;
  my $conf = $self->conf;

  my( $template, $invoice_from, $notice_name );
  my $agentnums = '';
  my $balance_over = 0;

  if ( ref($_[0]) ) {
    my $opt = shift;
    $template = $opt->{'template'} || '';
    if ( $agentnums = $opt->{'agentnum'} ) {
      $agentnums = [ $agentnums ] unless ref($agentnums);
    }
    $invoice_from = $opt->{'invoice_from'};
    $balance_over = $opt->{'balance_over'} if $opt->{'balance_over'};
    $notice_name = $opt->{'notice_name'};
  } else {
    $template = scalar(@_) ? shift : '';
    if ( scalar(@_) && $_[0]  ) {
      $agentnums = ref($_[0]) ? shift : [ shift ];
    }
    $invoice_from = shift if scalar(@_);
    $balance_over = shift if scalar(@_) && $_[0] !~ /^\s*$/;
  }

  my $cust_main = $self->cust_main;

  return 'N/A' unless ! $agentnums
                   or grep { $_ == $cust_main->agentnum } @$agentnums;

  return ''
    unless $cust_main->total_owed_date($self->_date) > $balance_over;

  $invoice_from ||= $self->_agent_invoice_from ||    #XXX should go away
                    $conf->config('invoice_from', $cust_main->agentnum );

  my %opt = (
    'template'     => $template,
    'invoice_from' => $invoice_from,
    'notice_name'  => ( $notice_name || 'Invoice' ),
  );

  my @invoicing_list = $cust_main->invoicing_list;

  #$self->email_invoice(\%opt)
  $self->email(\%opt)
    if ( grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list or !@invoicing_list )
    && ! $self->invoice_noemail;

  #$self->print_invoice(\%opt)
  $self->print(\%opt)
    if grep { $_ eq 'POST' } @invoicing_list; #postal

  $self->fax_invoice(\%opt)
    if grep { $_ eq 'FAX' } @invoicing_list; #fax

  '';

}

=item email HASHREF | [ TEMPLATE [ , INVOICE_FROM ] ] 

Emails this invoice.

Options can be passed as a hashref (recommended) or as a list of up to 
two values for templatename and invoice_from.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<invoice_from>, if specified, overrides the default email invoice From: address.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub queueable_email {
  my %opt = @_;

  my $self = qsearchs('cust_bill', { 'invnum' => $opt{invnum} } )
    or die "invalid invoice number: " . $opt{invnum};

  my %args = ( 'template' => $opt{template} );
  $args{$_} = $opt{$_}
    foreach grep { exists($opt{$_}) && $opt{$_} }
              qw( invoice_from notice_name no_coupon );

  my $error = $self->email( \%args );
  die $error if $error;

}

#sub email_invoice {
sub email {
  my $self = shift;
  return if $self->hide;
  my $conf = $self->conf;

  my( $template, $invoice_from, $notice_name, $no_coupon );
  if ( ref($_[0]) ) {
    my $opt = shift;
    $template = $opt->{'template'} || '';
    $invoice_from = $opt->{'invoice_from'};
    $notice_name = $opt->{'notice_name'} || 'Invoice';
    $no_coupon = $opt->{'no_coupon'} || 0;
  } else {
    $template = scalar(@_) ? shift : '';
    $invoice_from = shift if scalar(@_);
    $notice_name = 'Invoice';
    $no_coupon = 0;
  }

  $invoice_from ||= $self->_agent_invoice_from ||    #XXX should go away
                    $conf->config('invoice_from', $self->cust_main->agentnum );

  my @invoicing_list = grep { $_ !~ /^(POST|FAX)$/ } 
                            $self->cust_main->invoicing_list;

  if ( ! @invoicing_list ) { #no recipients
    if ( $conf->exists('cust_bill-no_recipients-error') ) {
      die 'No recipients for customer #'. $self->custnum;
    } else {
      #default: better to notify this person than silence
      @invoicing_list = ($invoice_from);
    }
  }

  my $subject = $self->email_subject($template);

  my $error = send_email(
    $self->generate_email(
      'from'        => $invoice_from,
      'to'          => [ grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list ],
      'subject'     => $subject,
      'template'    => $template,
      'notice_name' => $notice_name,
      'no_coupon'   => $no_coupon,
    )
  );
  die "can't email invoice: $error\n" if $error;
  #die "$error\n" if $error;

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

=item lpr_data HASHREF | [ TEMPLATE ]

Returns the postscript or plaintext for this invoice as an arrayref.

Options can be passed as a hashref (recommended) or as a single optional value
for template.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub lpr_data {
  my $self = shift;
  my $conf = $self->conf;
  my( $template, $notice_name );
  if ( ref($_[0]) ) {
    my $opt = shift;
    $template = $opt->{'template'} || '';
    $notice_name = $opt->{'notice_name'} || 'Invoice';
  } else {
    $template = scalar(@_) ? shift : '';
    $notice_name = 'Invoice';
  }

  my %opt = (
    'template'    => $template,
    'notice_name' => $notice_name,
  );

  my $method = $conf->exists('invoice_latex') ? 'print_ps' : 'print_text';
  [ $self->$method( \%opt ) ];
}

=item print HASHREF | [ TEMPLATE ]

Prints this invoice.

Options can be passed as a hashref (recommended) or as a single optional
value for template.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

#sub print_invoice {
sub print {
  my $self = shift;
  return if $self->hide;
  my $conf = $self->conf;

  my( $template, $notice_name );
  if ( ref($_[0]) ) {
    my $opt = shift;
    $template = $opt->{'template'} || '';
    $notice_name = $opt->{'notice_name'} || 'Invoice';
  } else {
    $template = scalar(@_) ? shift : '';
    $notice_name = 'Invoice';
  }

  my %opt = (
    'template'    => $template,
    'notice_name' => $notice_name,
  );

  if($conf->exists('invoice_print_pdf')) {
    # Add the invoice to the current batch.
    $self->batch_invoice(\%opt);
  }
  else {
    do_print(
      $self->lpr_data(\%opt),
      'agentnum' => $self->cust_main->agentnum,
    );
  }
}

=item fax_invoice HASHREF | [ TEMPLATE ] 

Faxes this invoice.

Options can be passed as a hashref (recommended) or as a single optional
value for template.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub fax_invoice {
  my $self = shift;
  return if $self->hide;
  my $conf = $self->conf;

  my( $template, $notice_name );
  if ( ref($_[0]) ) {
    my $opt = shift;
    $template = $opt->{'template'} || '';
    $notice_name = $opt->{'notice_name'} || 'Invoice';
  } else {
    $template = scalar(@_) ? shift : '';
    $notice_name = 'Invoice';
  }

  die 'FAX invoice destination not (yet?) supported with plain text invoices.'
    unless $conf->exists('invoice_latex');

  my $dialstring = $self->cust_main->getfield('fax');
  #Check $dialstring?

  my %opt = (
    'template'    => $template,
    'notice_name' => $notice_name,
  );

  my $error = send_fax( 'docdata'    => $self->lpr_data(\%opt),
                        'dialstring' => $dialstring,
                      );
  die $error if $error;

}

=item batch_invoice [ HASHREF ]

Place this invoice into the open batch (see C<FS::bill_batch>).  If there 
isn't an open batch, one will be created.

=cut

sub batch_invoice {
  my ($self, $opt) = @_;
  my $bill_batch = $self->get_open_bill_batch;
  my $cust_bill_batch = FS::cust_bill_batch->new({
      batchnum => $bill_batch->batchnum,
      invnum   => $self->invnum,
  });
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

=item send_if_newest [ TEMPLATENAME [ , AGENTNUM [ , INVOICE_FROM ] ] ]

Like B<send>, but only sends the invoice if it is the newest open invoice for
this customer.

=cut

sub send_if_newest {
  my $self = shift;

  return ''
    if scalar(
               grep { $_->owed > 0 } 
                    qsearch('cust_bill', {
                      'custnum' => $self->custnum,
                      #'_date'   => { op=>'>', value=>$self->_date },
                      'invnum'  => { op=>'>', value=>$self->invnum },
                    } )
             );
    
  $self->send(@_);
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

=item format - 'default' or 'billco'

=item dest - if set (to POST, EMAIL or FAX), only sends spools invoices if the customer has the corresponding invoice destinations set (see L<FS::cust_main_invoice>).

=item agent_spools - if set to a true value, will spool to per-agent files rather than a single global file

=item balanceover - if set, only spools the invoice if the total amount owed on this invoice and all older invoices is greater than the specified amount.

=back

=cut

sub spool_csv {
  my($self, %opt) = @_;

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

  my $tracctnum = $self->invnum. time2str('-%Y%m%d%H%M%S', time);

  my $file =
    "$spooldir/".
    ( $opt{'agent_spools'} ? 'agentnum'.$cust_main->agentnum : 'spool' ).
    ( lc($opt{'format'}) eq 'billco' ? '-header' : '' ) .
    '.csv';
  
  my ( $header, $detail ) = $self->print_csv(%opt, 'tracctnum' => $tracctnum );

  open(CSV, ">>$file") or die "can't open $file: $!";
  flock(CSV, LOCK_EX);
  seek(CSV, 0, 2);

  print CSV $header;

  if ( lc($opt{'format'}) eq 'billco' ) {

    flock(CSV, LOCK_UN);
    close CSV;

    $file =
      "$spooldir/".
      ( $opt{'agent_spools'} ? 'agentnum'.$cust_main->agentnum : 'spool' ).
      '-detail.csv';

    open(CSV,">>$file") or die "can't open $file: $!";
    flock(CSV, LOCK_EX);
    seek(CSV, 0, 2);
  }

  print CSV $detail;

  flock(CSV, LOCK_UN);
  close CSV;

  return '';

}

=item print_csv OPTION => VALUE, ...

Returns CSV data for this invoice.

Options are:

format - 'default' or 'billco'

Returns a list consisting of two scalars.  The first is a single line of CSV
header information for this invoice.  The second is one or more lines of CSV
detail information for this invoice.

If I<format> is not specified or "default", the fields of the CSV file are as
follows:

record_type, invnum, custnum, _date, charged, first, last, company, address1, address2, city, state, zip, country, pkg, setup, recur, sdate, edate

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

=cut

sub print_csv {
  my($self, %opt) = @_;
  
  eval "use Text::CSV_XS";
  die $@ if $@;

  my $cust_main = $self->cust_main;

  my $csv = Text::CSV_XS->new({'always_quote'=>1});

  if ( lc($opt{'format'}) eq 'billco' ) {

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
      $opt{'tracctnum'},          #  3 | Transaction Account No        CHAR  15
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

  } elsif ( lc($opt{'format'}) eq 'oneline' ) { #name?
  
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

  } else {
  
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
    foreach my $item ( $self->_items_pkg ) {

      $csv->combine(
        '',                     #  1 | N/A-Leave Empty            CHAR   2
        '',                     #  2 | N/A-Leave Empty            CHAR  15
        $opt{'tracctnum'},      #  3 | Account Number             CHAR  15
        $self->invnum,          #  4 | Invoice Number             CHAR  15
        $lineseq++,             #  5 | Line Sequence (sort order) NUM    6
        $item->{'description'}, #  6 | Transaction Detail         CHAR 100
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

=item comp

Pays this invoice with a compliemntary payment.  If there is an error,
returns the error, otherwise returns false.

=cut

sub comp {
  my $self = shift;
  my $cust_pay = new FS::cust_pay ( {
    'invnum'   => $self->invnum,
    'paid'     => $self->owed,
    '_date'    => '',
    'payby'    => 'COMP',
    'payinfo'  => $self->cust_main->payinfo,
    'paybatch' => '',
  } );
  $cust_pay->insert;
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

=item print_text HASHREF | [ TIME [ , TEMPLATE [ , OPTION => VALUE ... ] ] ]

Returns an text invoice, as a list of lines.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_text {
  my $self = shift;
  my( $today, $template, %opt );
  if ( ref($_[0]) ) {
    %opt = %{ shift() };
    $today = delete($opt{'time'}) || '';
    $template = delete($opt{template}) || '';
  } else {
    ( $today, $template, %opt ) = @_;
  }

  my %params = ( 'format' => 'template' );
  $params{'time'} = $today if $today;
  $params{'template'} = $template if $template;
  $params{$_} = $opt{$_} 
    foreach grep $opt{$_}, qw( unsquelch_cdr notice_name );

  $self->print_generic( %params );
}

=item print_latex HASHREF | [ TIME [ , TEMPLATE [ , OPTION => VALUE ... ] ] ]

Internal method - returns a filename of a filled-in LaTeX template for this
invoice (Note: add ".tex" to get the actual filename), and a filename of
an associated logo (with the .eps extension included).

See print_ps and print_pdf for methods that return PostScript and PDF output.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_latex {
  my $self = shift;
  my $conf = $self->conf;
  my( $today, $template, %opt );
  if ( ref($_[0]) ) {
    %opt = %{ shift() };
    $today = delete($opt{'time'}) || '';
    $template = delete($opt{template}) || '';
  } else {
    ( $today, $template, %opt ) = @_;
  }

  my %params = ( 'format' => 'latex' );
  $params{'time'} = $today if $today;
  $params{'template'} = $template if $template;
  $params{$_} = $opt{$_} 
    foreach grep $opt{$_}, qw( unsquelch_cdr notice_name );

  $template ||= $self->_agent_template;

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  my $lh = new File::Temp( TEMPLATE => 'invoice.'. $self->invnum. '.XXXXXXXX',
                           DIR      => $dir,
                           SUFFIX   => '.eps',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";

  my $agentnum = $self->cust_main->agentnum;

  if ( $template && $conf->exists("logo_${template}.eps", $agentnum) ) {
    print $lh $conf->config_binary("logo_${template}.eps", $agentnum)
      or die "can't write temp file: $!\n";
  } else {
    print $lh $conf->config_binary('logo.eps', $agentnum)
      or die "can't write temp file: $!\n";
  }
  close $lh;
  $params{'logo_file'} = $lh->filename;

  if($conf->exists('invoice-barcode')){
      my $png_file = $self->invoice_barcode($dir);
      my $eps_file = $png_file;
      $eps_file =~ s/\.png$/.eps/g;
      $png_file =~ /(barcode.*png)/;
      $png_file = $1;
      $eps_file =~ /(barcode.*eps)/;
      $eps_file = $1;

      my $curr_dir = cwd();
      chdir($dir); 
      # after painfuly long experimentation, it was determined that sam2p won't
      #	accept : and other chars in the path, no matter how hard I tried to
      # escape them, hence the chdir (and chdir back, just to be safe)
      system('sam2p', '-j:quiet', $png_file, 'EPS:', $eps_file ) == 0
	or die "sam2p failed: $!\n";
      unlink($png_file);
      chdir($curr_dir);

      $params{'barcode_file'} = $eps_file;
  }

  my @filled_in = $self->print_generic( %params );
  
  my $fh = new File::Temp( TEMPLATE => 'invoice.'. $self->invnum. '.XXXXXXXX',
                           DIR      => $dir,
                           SUFFIX   => '.tex',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";
  binmode($fh, ':utf8'); # language support
  print $fh join('', @filled_in );
  close $fh;

  $fh->filename =~ /^(.*).tex$/ or die "unparsable filename: ". $fh->filename;
  return ($1, $params{'logo_file'}, $params{'barcode_file'});

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

=item print_generic OPTION => VALUE ...

Internal method - returns a filled-in template for this invoice as a scalar.

See print_ps and print_pdf for methods that return PostScript and PDF output.

Non optional options include 
  format - latex, html, template

Optional options include

template - a value used as a suffix for a configuration template

time - a value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

cid - 

unsquelch_cdr - overrides any per customer cdr squelching when true

notice_name - overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

locale - override customer's locale

=cut

#what's with all the sprintf('%10.2f')'s in here?  will it cause any
# (alignment in text invoice?) problems to change them all to '%.2f' ?
# yes: fixed width/plain text printing will be borked
sub print_generic {
  my( $self, %params ) = @_;
  my $conf = $self->conf;
  my $today = $params{today} ? $params{today} : time;
  warn "$me print_generic called on $self with suffix $params{template}\n"
    if $DEBUG;

  my $format = $params{format};
  die "Unknown format: $format"
    unless $format =~ /^(latex|html|template)$/;

  my $cust_main = $self->cust_main;
  $cust_main->payname( $cust_main->first. ' '. $cust_main->getfield('last') )
    unless $cust_main->payname
        && $cust_main->payby !~ /^(CARD|DCRD|CHEK|DCHK)$/;

  my %delimiters = ( 'latex'    => [ '[@--', '--@]' ],
                     'html'     => [ '<%=', '%>' ],
                     'template' => [ '{', '}' ],
                   );

  warn "$me print_generic creating template\n"
    if $DEBUG > 1;

  #create the template
  my $template = $params{template} ? $params{template} : $self->_agent_template;
  my $templatefile = "invoice_$format";
  $templatefile .= "_$template"
    if length($template) && $conf->exists($templatefile."_$template");
  my @invoice_template = map "$_\n", $conf->config($templatefile)
    or die "cannot load config data $templatefile";

  my $old_latex = '';
  if ( $format eq 'latex' && grep { /^%%Detail/ } @invoice_template ) {
    #change this to a die when the old code is removed
    warn "old-style invoice template $templatefile; ".
         "patch with conf/invoice_latex.diff or use new conf/invoice_latex*\n";
    $old_latex = 'true';
    @invoice_template = _translate_old_latex_format(@invoice_template);
  } 

  warn "$me print_generic creating T:T object\n"
    if $DEBUG > 1;

  my $text_template = new Text::Template(
    TYPE => 'ARRAY',
    SOURCE => \@invoice_template,
    DELIMITERS => $delimiters{$format},
  );

  warn "$me print_generic compiling T:T object\n"
    if $DEBUG > 1;

  $text_template->compile()
    or die "Can't compile $templatefile: $Text::Template::ERROR\n";


  # additional substitution could possibly cause breakage in existing templates
  my %convert_maps = ( 
    'latex' => {
                 'notes'         => sub { map "$_", @_ },
                 'footer'        => sub { map "$_", @_ },
                 'smallfooter'   => sub { map "$_", @_ },
                 'returnaddress' => sub { map "$_", @_ },
                 'coupon'        => sub { map "$_", @_ },
                 'summary'       => sub { map "$_", @_ },
               },
    'html'  => {
                 'notes' =>
                   sub {
                     map { 
                       s/%%(.*)$/<!-- $1 -->/g;
                       s/\\section\*\{\\textsc\{(.)(.*)\}\}/<p><b><font size="+1">$1<\/font>\U$2<\/b>/g;
                       s/\\begin\{enumerate\}/<ol>/g;
                       s/\\item /  <li>/g;
                       s/\\end\{enumerate\}/<\/ol>/g;
                       s/\\textbf\{(.*)\}/<b>$1<\/b>/g;
                       s/\\\\\*/<br>/g;
                       s/\\dollar ?/\$/g;
                       s/\\#/#/g;
                       s/~/&nbsp;/g;
                       $_;
                     }  @_
                   },
                 'footer' =>
                   sub { map { s/~/&nbsp;/g; s/\\\\\*?\s*$/<BR>/; $_; } @_ },
                 'smallfooter' =>
                   sub { map { s/~/&nbsp;/g; s/\\\\\*?\s*$/<BR>/; $_; } @_ },
                 'returnaddress' =>
                   sub {
                     map { 
                       s/~/&nbsp;/g;
                       s/\\\\\*?\s*$/<BR>/;
                       s/\\hyphenation\{[\w\s\-]+}//;
                       s/\\([&])/$1/g;
                       $_;
                     }  @_
                   },
                 'coupon'        => sub { "" },
                 'summary'       => sub { "" },
               },
    'template' => {
                 'notes' =>
                   sub {
                     map { 
                       s/%%.*$//g;
                       s/\\section\*\{\\textsc\{(.*)\}\}/\U$1/g;
                       s/\\begin\{enumerate\}//g;
                       s/\\item /  * /g;
                       s/\\end\{enumerate\}//g;
                       s/\\textbf\{(.*)\}/$1/g;
                       s/\\\\\*/ /;
                       s/\\dollar ?/\$/g;
                       $_;
                     }  @_
                   },
                 'footer' =>
                   sub { map { s/~/ /g; s/\\\\\*?\s*$/\n/; $_; } @_ },
                 'smallfooter' =>
                   sub { map { s/~/ /g; s/\\\\\*?\s*$/\n/; $_; } @_ },
                 'returnaddress' =>
                   sub {
                     map { 
                       s/~/ /g;
                       s/\\\\\*?\s*$/\n/;             # dubious
                       s/\\hyphenation\{[\w\s\-]+}//;
                       $_;
                     }  @_
                   },
                 'coupon'        => sub { "" },
                 'summary'       => sub { "" },
               },
  );


  # hashes for differing output formats
  my %nbsps = ( 'latex'    => '~',
                'html'     => '',    # '&nbps;' would be nice
                'template' => '',    # not used
              );
  my $nbsp = $nbsps{$format};

  my %escape_functions = ( 'latex'    => \&_latex_escape,
                           'html'     => \&_html_escape_nbsp,#\&encode_entities,
                           'template' => sub { shift },
                         );
  my $escape_function = $escape_functions{$format};
  my $escape_function_nonbsp = ($format eq 'html')
                                 ? \&_html_escape : $escape_function;

  my %embolden_functions = ( 'latex'    => sub { return '\textbf{'. shift(). '}'
                                               },
                             'html'     => sub { return '<b>'. shift(). '</b>'
                                               },
                             'template' => sub { shift },
                           );
  my $embolden_function = $embolden_functions{$format};

  my %newline_tokens = (  'latex'     => '\\\\',
                          'html'      => '<br>',
                          'template'  => "\n",
                        );
  my $newline_token = $newline_tokens{$format};

  warn "$me generating template variables\n"
    if $DEBUG > 1;

  # generate template variables
  my $returnaddress;
  if (
         defined( $conf->config_orbase( "invoice_${format}returnaddress",
                                        $template
                                      )
                )
       && length( $conf->config_orbase( "invoice_${format}returnaddress",
                                        $template
                                      )
                )
  ) {

    $returnaddress = join("\n",
      $conf->config_orbase("invoice_${format}returnaddress", $template)
    );

  } elsif ( grep /\S/,
            $conf->config_orbase('invoice_latexreturnaddress', $template) ) {

    my $convert_map = $convert_maps{$format}{'returnaddress'};
    $returnaddress =
      join( "\n",
            &$convert_map( $conf->config_orbase( "invoice_latexreturnaddress",
                                                 $template
                                               )
                         )
          );
  } elsif ( grep /\S/, $conf->config('company_address', $self->cust_main->agentnum) ) {

    my $convert_map = $convert_maps{$format}{'returnaddress'};
    $returnaddress = join( "\n", &$convert_map(
                                   map { s/( {2,})/'~' x length($1)/eg;
                                         s/$/\\\\\*/;
                                         $_
                                       }
                                     ( $conf->config('company_name', $self->cust_main->agentnum),
                                       $conf->config('company_address', $self->cust_main->agentnum),
                                     )
                                 )
                     );

  } else {

    my $warning = "Couldn't find a return address; ".
                  "do you need to set the company_address configuration value?";
    warn "$warning\n";
    $returnaddress = $nbsp;
    #$returnaddress = $warning;

  }

  warn "$me generating invoice data\n"
    if $DEBUG > 1;

  my $agentnum = $self->cust_main->agentnum;

  my %invoice_data = (

    #invoice from info
    'company_name'    => scalar( $conf->config('company_name', $agentnum) ),
    'company_address' => join("\n", $conf->config('company_address', $agentnum) ). "\n",
    'company_phonenum'=> scalar( $conf->config('company_phonenum', $agentnum) ),
    'returnaddress'   => $returnaddress,
    'agent'           => &$escape_function($cust_main->agent->agent),

    #invoice info
    'invnum'          => $self->invnum,
    '_date'           => $self->_date,
    'date'            => $self->time2str_local('long', $self->_date, $format),
    'today'           => $self->time2str_local('long', $today, $format),
    'terms'           => $self->terms,
    'template'        => $template, #params{'template'},
    'notice_name'     => ($params{'notice_name'} || 'Invoice'),#escape_function?
    'current_charges' => sprintf("%.2f", $self->charged),
    'duedate'         => $self->due_date2str('rdate'),

    #customer info
    'custnum'         => $cust_main->display_custnum,
    'agent_custid'    => &$escape_function($cust_main->agent_custid),
    ( map { $_ => &$escape_function($cust_main->$_()) } qw(
      payname company address1 address2 city state zip fax
    )),

    #global config
    'ship_enable'     => $conf->exists('invoice-ship_address'),
    'unitprices'      => $conf->exists('invoice-unitprice'),
    'smallernotes'    => $conf->exists('invoice-smallernotes'),
    'smallerfooter'   => $conf->exists('invoice-smallerfooter'),
    'balance_due_below_line' => $conf->exists('balance_due_below_line'),
   
    #layout info -- would be fancy to calc some of this and bury the template
    #               here in the code
    'topmargin'             => scalar($conf->config('invoice_latextopmargin', $agentnum)),
    'headsep'               => scalar($conf->config('invoice_latexheadsep', $agentnum)),
    'textheight'            => scalar($conf->config('invoice_latextextheight', $agentnum)),
    'extracouponspace'      => scalar($conf->config('invoice_latexextracouponspace', $agentnum)),
    'couponfootsep'         => scalar($conf->config('invoice_latexcouponfootsep', $agentnum)),
    'verticalreturnaddress' => $conf->exists('invoice_latexverticalreturnaddress', $agentnum),
    'addresssep'            => scalar($conf->config('invoice_latexaddresssep', $agentnum)),
    'amountenclosedsep'     => scalar($conf->config('invoice_latexcouponamountenclosedsep', $agentnum)),
    'coupontoaddresssep'    => scalar($conf->config('invoice_latexcoupontoaddresssep', $agentnum)),
    'addcompanytoaddress'   => $conf->exists('invoice_latexcouponaddcompanytoaddress', $agentnum),

    # better hang on to conf_dir for a while (for old templates)
    'conf_dir'        => "$FS::UID::conf_dir/conf.$FS::UID::datasrc",

    #these are only used when doing paged plaintext
    'page'            => 1,
    'total_pages'     => 1,

  );
 
  #localization (see FS::cust_main_Mixin)
  $invoice_data{'emt'} = sub { &$escape_function($self->mt(@_)) };
  # prototype here to silence warnings
  $invoice_data{'time2str'} = sub ($;$$) { $self->time2str_local(@_, $format) };

  my $min_sdate = 999999999999;
  my $max_edate = 0;
  foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
    next unless $cust_bill_pkg->pkgnum > 0;
    $min_sdate = $cust_bill_pkg->sdate
      if length($cust_bill_pkg->sdate) && $cust_bill_pkg->sdate < $min_sdate;
    $max_edate = $cust_bill_pkg->edate
      if length($cust_bill_pkg->edate) && $cust_bill_pkg->edate > $max_edate;
  }

  $invoice_data{'bill_period'} = '';
  $invoice_data{'bill_period'} =
      $self->time2str_local('%e %h', $min_sdate, $format) 
      . " to " .
      $self->time2str_local('%e %h', $max_edate, $format)
    if ($max_edate != 0 && $min_sdate != 999999999999);

  $invoice_data{finance_section} = '';
  if ( $conf->config('finance_pkgclass') ) {
    my $pkg_class =
      qsearchs('pkg_class', { classnum => $conf->config('finance_pkgclass') });
    $invoice_data{finance_section} = $pkg_class->categoryname;
  } 
  $invoice_data{finance_amount} = '0.00';
  $invoice_data{finance_section} ||= 'Finance Charges'; #avoid config confusion

  my $countrydefault = $conf->config('countrydefault') || 'US';
  my $prefix = $cust_main->has_ship_address ? 'ship_' : '';
  foreach ( qw( contact company address1 address2 city state zip country fax) ){
    my $method = $prefix.$_;
    $invoice_data{"ship_$_"} = _latex_escape($cust_main->$method);
  }
  $invoice_data{'ship_country'} = ''
    if ( $invoice_data{'ship_country'} eq $countrydefault );
  
  $invoice_data{'cid'} = $params{'cid'}
    if $params{'cid'};

  if ( $cust_main->country eq $countrydefault ) {
    $invoice_data{'country'} = '';
  } else {
    $invoice_data{'country'} = &$escape_function(code2country($cust_main->country));
  }

  my @address = ();
  $invoice_data{'address'} = \@address;
  push @address,
    $cust_main->payname.
      ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo
        ? " (P.O. #". $cust_main->payinfo. ")"
        : ''
      )
  ;
  push @address, $cust_main->company
    if $cust_main->company;
  push @address, $cust_main->address1;
  push @address, $cust_main->address2
    if $cust_main->address2;
  push @address,
    $cust_main->city. ", ". $cust_main->state. "  ".  $cust_main->zip;
  push @address, $invoice_data{'country'}
    if $invoice_data{'country'};
  push @address, ''
    while (scalar(@address) < 5);

  $invoice_data{'logo_file'} = $params{'logo_file'}
    if $params{'logo_file'};
  $invoice_data{'barcode_file'} = $params{'barcode_file'}
    if $params{'barcode_file'};
  $invoice_data{'barcode_img'} = $params{'barcode_img'}
    if $params{'barcode_img'};
  $invoice_data{'barcode_cid'} = $params{'barcode_cid'}
    if $params{'barcode_cid'};

  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
#  my( $cr_total, @cr_cust_credit ) = $self->cust_credit; #credits
  #my $balance_due = $self->owed + $pr_total - $cr_total;
  my $balance_due = $self->owed + $pr_total;

  # the customer's current balance as shown on the invoice before this one
  $invoice_data{'true_previous_balance'} = sprintf("%.2f", ($self->previous_balance || 0) );

  # the change in balance from that invoice to this one
  $invoice_data{'balance_adjustments'} = sprintf("%.2f", ($self->previous_balance || 0) - ($self->billing_balance || 0) );

  # the sum of amount owed on all previous invoices
  $invoice_data{'previous_balance'} = sprintf("%.2f", $pr_total);

  # the sum of amount owed on all invoices
  $invoice_data{'balance'} = sprintf("%.2f", $balance_due);

  # info from customer's last invoice before this one, for some 
  # summary formats
  $invoice_data{'last_bill'} = {};
  if ( $self->previous_bill ) {
    $invoice_data{'last_bill'} = {
      '_date'     => $self->previous_bill->_date, #unformatted
      # all we need for now
    };
  }

  my $summarypage = '';
  if ( $conf->exists('invoice_usesummary', $agentnum) ) {
    $summarypage = 1;
  }
  $invoice_data{'summarypage'} = $summarypage;

  warn "$me substituting variables in notes, footer, smallfooter\n"
    if $DEBUG > 1;

  my @include = (qw( notes footer smallfooter ));
  push @include, 'coupon' unless $params{'no_coupon'};
  foreach my $include (@include) {

    my $inc_file = $conf->key_orbase("invoice_${format}$include", $template);
    my @inc_src;

    if ( $conf->exists($inc_file, $agentnum)
         && length( $conf->config($inc_file, $agentnum) ) ) {

      @inc_src = $conf->config($inc_file, $agentnum);

    } else {

      $inc_file = $conf->key_orbase("invoice_latex$include", $template);

      my $convert_map = $convert_maps{$format}{$include};

      @inc_src = map { s/\[\@--/$delimiters{$format}[0]/g;
                       s/--\@\]/$delimiters{$format}[1]/g;
                       $_;
                     } 
                 &$convert_map( $conf->config($inc_file, $agentnum) );

    }

    my $inc_tt = new Text::Template (
      TYPE       => 'ARRAY',
      SOURCE     => [ map "$_\n", @inc_src ],
      DELIMITERS => $delimiters{$format},
    ) or die "Can't create new Text::Template object: $Text::Template::ERROR";

    unless ( $inc_tt->compile() ) {
      my $error = "Can't compile $inc_file template: $Text::Template::ERROR\n";
      warn $error. "Template:\n". join('', map "$_\n", @inc_src);
      die $error;
    }

    $invoice_data{$include} = $inc_tt->fill_in( HASH => \%invoice_data );

    $invoice_data{$include} =~ s/\n+$//
      if ($format eq 'latex');
  }

  # let invoices use either of these as needed
  $invoice_data{'po_num'} = ($cust_main->payby eq 'BILL') 
    ? $cust_main->payinfo : '';
  $invoice_data{'po_line'} = 
    (  $cust_main->payby eq 'BILL' && $cust_main->payinfo )
      ? &$escape_function($self->mt("Purchase Order #").$cust_main->payinfo)
      : $nbsp;

  my %money_chars = ( 'latex'    => '',
                      'html'     => $conf->config('money_char') || '$',
                      'template' => '',
                    );
  my $money_char = $money_chars{$format};

  my %other_money_chars = ( 'latex'    => '\dollar ',#XXX should be a config too
                            'html'     => $conf->config('money_char') || '$',
                            'template' => '',
                          );
  my $other_money_char = $other_money_chars{$format};
  $invoice_data{'dollar'} = $other_money_char;

  my @detail_items = ();
  my @total_items = ();
  my @buf = ();
  my @sections = ();

  $invoice_data{'detail_items'} = \@detail_items;
  $invoice_data{'total_items'} = \@total_items;
  $invoice_data{'buf'} = \@buf;
  $invoice_data{'sections'} = \@sections;

  warn "$me generating sections\n"
    if $DEBUG > 1;

  my $previous_section = { 'description' => $self->mt('Previous Charges'),
                           'subtotal'    => $other_money_char.
                                            sprintf('%.2f', $pr_total),
                           'summarized'  => '', #why? $summarypage ? 'Y' : '',
                         };
  $previous_section->{posttotal} = '0 / 30 / 60 / 90 days overdue '. 
    join(' / ', map { $cust_main->balance_date_range(@$_) }
                $self->_prior_month30s
        )
    if $conf->exists('invoice_include_aging');

  my $taxtotal = 0;
  my $tax_section = { 'description' => $self->mt('Taxes, Surcharges, and Fees'),
                      'subtotal'    => $taxtotal,   # adjusted below
                      'tax_section' => 1,
                    };
  my $tax_weight = _pkg_category($tax_section->{description})
                        ? _pkg_category($tax_section->{description})->weight
                        : 0;
  $tax_section->{'summarized'} = ''; #why? $summarypage && !$tax_weight ? 'Y' : '';
  $tax_section->{'sort_weight'} = $tax_weight;


  my $adjusttotal = 0;
  my $adjust_section = {
    'description'    => $self->mt('Credits, Payments, and Adjustments'),
    'adjust_section' => 1,
    'subtotal'       => 0,   # adjusted below
  };
  my $adjust_weight = _pkg_category($adjust_section->{description})
                        ? _pkg_category($adjust_section->{description})->weight
                        : 0;
  $adjust_section->{'summarized'} = ''; #why? $summarypage && !$adjust_weight ? 'Y' : '';
  $adjust_section->{'sort_weight'} = $adjust_weight;

  my $unsquelched = $params{unsquelch_cdr} || $cust_main->squelch_cdr ne 'Y';
  my $multisection = $conf->exists('invoice_sections', $cust_main->agentnum);
  $invoice_data{'multisection'} = $multisection;
  my $late_sections = [];
  my $extra_sections = [];
  my $extra_lines = ();

  my $default_section = { 'description' => '',
                          'subtotal'    => '', 
                          'no_subtotal' => 1,
                        };

  if ( $multisection ) {
    ($extra_sections, $extra_lines) =
      $self->_items_extra_usage_sections($escape_function_nonbsp, $format)
      if $conf->exists('usage_class_as_a_section', $cust_main->agentnum);

    push @$extra_sections, $adjust_section if $adjust_section->{sort_weight};

    push @detail_items, @$extra_lines if $extra_lines;
    push @sections,
      $self->_items_sections( $late_sections,      # this could stand a refactor
                              $summarypage,
                              $escape_function_nonbsp,
                              $extra_sections,
                              $format,             #bah
                            );
    if ($conf->exists('svc_phone_sections')) {
      my ($phone_sections, $phone_lines) =
        $self->_items_svc_phone_sections($escape_function_nonbsp, $format);
      push @{$late_sections}, @$phone_sections;
      push @detail_items, @$phone_lines;
    }
    if ($conf->exists('voip-cust_accountcode_cdr') && $cust_main->accountcode_cdr) {
      my ($accountcode_section, $accountcode_lines) =
        $self->_items_accountcode_cdr($escape_function_nonbsp,$format);
      if ( scalar(@$accountcode_lines) ) {
          push @{$late_sections}, $accountcode_section;
          push @detail_items, @$accountcode_lines;
      }
    }
  } else {# not multisection
    # make a default section
    push @sections, $default_section;
    # and calculate the finance charge total, since it won't get done otherwise.
    # XXX possibly other totals?
    # XXX possibly finance_pkgclass should not be used in this manner?
    if ( $conf->exists('finance_pkgclass') ) {
      my @finance_charges;
      foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
        if ( grep { $_->section eq $invoice_data{finance_section} }
             $cust_bill_pkg->cust_bill_pkg_display ) {
          # I think these are always setup fees, but just to be sure...
          push @finance_charges, $cust_bill_pkg->recur + $cust_bill_pkg->setup;
        }
      }
      $invoice_data{finance_amount} = 
        sprintf('%.2f', sum( @finance_charges ) || 0);
    }
  }

  # previous invoice balances in the Previous Charges section if there
  # is one, otherwise in the main detail section
  if ( $self->can('_items_previous') &&
       $self->enable_previous &&
       ! $conf->exists('previous_balance-summary_only') ) {

    warn "$me adding previous balances\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_previous ) {

      my $detail = {
        ext_description => [],
      };
      $detail->{'ref'} = $line_item->{'pkgnum'};
      $detail->{'pkgpart'} = $line_item->{'pkgpart'};
      $detail->{'quantity'} = 1;
      $detail->{'section'} = $multisection ? $previous_section
                                           : $default_section;
      $detail->{'description'} = &$escape_function($line_item->{'description'});
      if ( exists $line_item->{'ext_description'} ) {
        @{$detail->{'ext_description'}} = map {
          &$escape_function($_);
        } @{$line_item->{'ext_description'}};
      }
      $detail->{'amount'} = ( $old_latex ? '' : $money_char).
                            $line_item->{'amount'};
      $detail->{'product_code'} = $line_item->{'pkgpart'} || 'N/A';

      push @detail_items, $detail;
      push @buf, [ $detail->{'description'},
                   $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                 ];
    }

  }

  if ( @pr_cust_bill && $self->enable_previous ) {
    push @buf, ['','-----------'];
    push @buf, [ $self->mt('Total Previous Balance'),
                 $money_char. sprintf("%10.2f", $pr_total) ];
    push @buf, ['',''];
  }
 
  if ( $conf->exists('svc_phone-did-summary') ) {
      warn "$me adding DID summary\n"
        if $DEBUG > 1;

      my ($didsummary,$minutes) = $self->_did_summary;
      my $didsummary_desc = 'DID Activity Summary (since last invoice)';
      push @detail_items, 
       { 'description' => $didsummary_desc,
           'ext_description' => [ $didsummary, $minutes ],
       };
  }

  foreach my $section (@sections, @$late_sections) {

    warn "$me adding section \n". Dumper($section)
      if $DEBUG > 1;

    # begin some normalization
    $section->{'subtotal'} = $section->{'amount'}
      if $multisection
         && !exists($section->{subtotal})
         && exists($section->{amount});

    $invoice_data{finance_amount} = sprintf('%.2f', $section->{'subtotal'} )
      if ( $invoice_data{finance_section} &&
           $section->{'description'} eq $invoice_data{finance_section} );

    $section->{'subtotal'} = $other_money_char.
                             sprintf('%.2f', $section->{'subtotal'})
      if $multisection;

    # continue some normalization
    $section->{'amount'}   = $section->{'subtotal'}
      if $multisection;


    if ( $section->{'description'} ) {
      push @buf, ( [ &$escape_function($section->{'description'}), '' ],
                   [ '', '' ],
                 );
    }

    warn "$me   setting options\n"
      if $DEBUG > 1;

    my $multilocation = scalar($cust_main->cust_location); #too expensive?
    my %options = ();
    $options{'section'} = $section if $multisection;
    $options{'format'} = $format;
    $options{'escape_function'} = $escape_function;
    $options{'no_usage'} = 1 unless $unsquelched;
    $options{'unsquelched'} = $unsquelched;
    $options{'summary_page'} = $summarypage;
    $options{'skip_usage'} =
      scalar(@$extra_sections) && !grep{$section == $_} @$extra_sections;
    $options{'multilocation'} = $multilocation;
    $options{'multisection'} = $multisection;

    warn "$me   searching for line items\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_pkg(%options) ) {

      warn "$me     adding line item $line_item\n"
        if $DEBUG > 1;

      my $detail = {
        ext_description => [],
      };
      $detail->{'ref'} = $line_item->{'pkgnum'};
      $detail->{'pkgpart'} = $line_item->{'pkgpart'};
      $detail->{'quantity'} = $line_item->{'quantity'};
      $detail->{'section'} = $section;
      $detail->{'description'} = &$escape_function($line_item->{'description'});
      if ( exists $line_item->{'ext_description'} ) {
        @{$detail->{'ext_description'}} = @{$line_item->{'ext_description'}};
      }
      $detail->{'amount'} = ( $old_latex ? '' : $money_char ).
                              $line_item->{'amount'};
      $detail->{'unit_amount'} = ( $old_latex ? '' : $money_char ).
                                 $line_item->{'unit_amount'};
      $detail->{'product_code'} = $line_item->{'pkgpart'} || 'N/A';

      $detail->{'sdate'} = $line_item->{'sdate'};
      $detail->{'edate'} = $line_item->{'edate'};
      $detail->{'seconds'} = $line_item->{'seconds'};
      $detail->{'svc_label'} = $line_item->{'svc_label'};
  
      push @detail_items, $detail;
      push @buf, ( [ $detail->{'description'},
                     $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                   ],
                   map { [ " ". $_, '' ] } @{$detail->{'ext_description'}},
                 );
    }

    if ( $section->{'description'} ) {
      push @buf, ( ['','-----------'],
                   [ $section->{'description'}. ' sub-total',
                      $section->{'subtotal'} # already formatted this 
                   ],
                   [ '', '' ],
                   [ '', '' ],
                 );
    }
  
  }

  $invoice_data{current_less_finance} =
    sprintf('%.2f', $self->charged - $invoice_data{finance_amount} );

  # create a major section for previous balance if we have major sections,
  # or if previous_section is in summary form
  if ( ( $multisection && $self->enable_previous )
    || $conf->exists('previous_balance-summary_only') )
  {
    unshift @sections, $previous_section if $pr_total;
  }

  warn "$me adding taxes\n"
    if $DEBUG > 1;

  foreach my $tax ( $self->_items_tax ) {

    $taxtotal += $tax->{'amount'};

    my $description = &$escape_function( $tax->{'description'} );
    my $amount      = sprintf( '%.2f', $tax->{'amount'} );

    if ( $multisection ) {

      my $money = $old_latex ? '' : $money_char;
      push @detail_items, {
        ext_description => [],
        ref          => '',
        quantity     => '',
        description  => $description,
        amount       => $money. $amount,
        product_code => '',
        section      => $tax_section,
      };

    } else {

      push @total_items, {
        'total_item'   => $description,
        'total_amount' => $other_money_char. $amount,
      };

    }

    push @buf,[ $description,
                $money_char. $amount,
              ];

  }
  
  if ( $taxtotal ) {
    my $total = {};
    $total->{'total_item'} = $self->mt('Sub-total');
    $total->{'total_amount'} =
      $other_money_char. sprintf('%.2f', $self->charged - $taxtotal );

    if ( $multisection ) {
      $tax_section->{'subtotal'} = $other_money_char.
                                   sprintf('%.2f', $taxtotal);
      $tax_section->{'pretotal'} = 'New charges sub-total '.
                                   $total->{'total_amount'};
      push @sections, $tax_section if $taxtotal;
    }else{
      unshift @total_items, $total;
    }
  }
  $invoice_data{'taxtotal'} = sprintf('%.2f', $taxtotal);

  push @buf,['','-----------'];
  push @buf,[$self->mt( 
              (!$self->enable_previous)
               ? 'Total Charges'
               : 'Total New Charges'
             ),
             $money_char. sprintf("%10.2f",$self->charged) ];
  push @buf,['',''];

  # calculate total, possibly including total owed on previous
  # invoices
  {
    my $total = {};
    my $item = 'Total';
    $item = $conf->config('previous_balance-exclude_from_total')
         || 'Total New Charges'
      if $conf->exists('previous_balance-exclude_from_total');
    my $amount = $self->charged;
    if ( $self->enable_previous and !$conf->exists('previous_balance-exclude_from_total') ) {
      $amount += $pr_total;
    }

    $total->{'total_item'} = &$embolden_function($self->mt($item));
    $total->{'total_amount'} =
      &$embolden_function( $other_money_char.  sprintf( '%.2f', $amount ) );
    if ( $multisection ) {
      if ( $adjust_section->{'sort_weight'} ) {
        $adjust_section->{'posttotal'} = $self->mt('Balance Forward').' '.
          $other_money_char.  sprintf("%.2f", ($self->billing_balance || 0) );
      } else {
        $adjust_section->{'pretotal'} = $self->mt('New charges total').' '.
          $other_money_char.  sprintf('%.2f', $self->charged );
      } 
    } else {
      push @total_items, $total;
    }
    push @buf,['','-----------'];
    push @buf,[$item,
               $money_char.
               sprintf( '%10.2f', $amount )
              ];
    push @buf,['',''];
  }

  # if we're showing previous invoices, also show previous
  # credits and payments 
  if ( $self->enable_previous 
        and $self->can('_items_credits')
        and $self->can('_items_payments') )
    {
    #foreach my $thing ( sort { $a->_date <=> $b->_date } $self->_items_credits, $self->_items_payments
  
    # credits
    my $credittotal = 0;
    foreach my $credit (
      $self->_items_credits( 'template' => $template, 'trim_len' => 60)
    ) {

      my $total;
      $total->{'total_item'} = &$escape_function($credit->{'description'});
      $credittotal += $credit->{'amount'};
      $total->{'total_amount'} = '-'. $other_money_char. $credit->{'amount'};
      $adjusttotal += $credit->{'amount'};
      if ( $multisection ) {
        my $money = $old_latex ? '' : $money_char;
        push @detail_items, {
          ext_description => [],
          ref          => '',
          quantity     => '',
          description  => &$escape_function($credit->{'description'}),
          amount       => $money. $credit->{'amount'},
          product_code => '',
          section      => $adjust_section,
        };
      } else {
        push @total_items, $total;
      }

    }
    $invoice_data{'credittotal'} = sprintf('%.2f', $credittotal);

    #credits (again)
    foreach my $credit (
      $self->_items_credits( 'template' => $template, 'trim_len' => 32)
    ) {
      push @buf, [ $credit->{'description'}, $money_char.$credit->{'amount'} ];
    }

    # payments
    my $paymenttotal = 0;
    foreach my $payment (
      $self->_items_payments( 'template' => $template )
    ) {
      my $total = {};
      $total->{'total_item'} = &$escape_function($payment->{'description'});
      $paymenttotal += $payment->{'amount'};
      $total->{'total_amount'} = '-'. $other_money_char. $payment->{'amount'};
      $adjusttotal += $payment->{'amount'};
      if ( $multisection ) {
        my $money = $old_latex ? '' : $money_char;
        push @detail_items, {
          ext_description => [],
          ref          => '',
          quantity     => '',
          description  => &$escape_function($payment->{'description'}),
          amount       => $money. $payment->{'amount'},
          product_code => '',
          section      => $adjust_section,
        };
      }else{
        push @total_items, $total;
      }
      push @buf, [ $payment->{'description'},
                   $money_char. sprintf("%10.2f", $payment->{'amount'}),
                 ];
    }
    $invoice_data{'paymenttotal'} = sprintf('%.2f', $paymenttotal);
  
    if ( $multisection ) {
      $adjust_section->{'subtotal'} = $other_money_char.
                                      sprintf('%.2f', $adjusttotal);
      push @sections, $adjust_section
        unless $adjust_section->{sort_weight};
    }

    # create Balance Due message
    { 
      my $total;
      $total->{'total_item'} = &$embolden_function($self->balance_due_msg);
      $total->{'total_amount'} =
        &$embolden_function(
          $other_money_char. sprintf('%.2f', #why? $summarypage 
                                             #  ? $self->charged +
                                             #    $self->billing_balance
                                             #  :
                                                 $self->owed + $pr_total
                                    )
        );
      if ( $multisection && !$adjust_section->{sort_weight} ) {
        $adjust_section->{'posttotal'} = $total->{'total_item'}. ' '.
                                         $total->{'total_amount'};
      }else{
        push @total_items, $total;
      }
      push @buf,['','-----------'];
      push @buf,[$self->balance_due_msg, $money_char. 
        sprintf("%10.2f", $balance_due ) ];
    }

    if ( $conf->exists('previous_balance-show_credit')
        and $cust_main->balance < 0 ) {
      my $credit_total = {
        'total_item'    => &$embolden_function($self->credit_balance_msg),
        'total_amount'  => &$embolden_function(
          $other_money_char. sprintf('%.2f', -$cust_main->balance)
        ),
      };
      if ( $multisection ) {
        $adjust_section->{'posttotal'} .= $newline_token .
          $credit_total->{'total_item'} . ' ' . $credit_total->{'total_amount'};
      }
      else {
        push @total_items, $credit_total;
      }
      push @buf,['','-----------'];
      push @buf,[$self->credit_balance_msg, $money_char. 
        sprintf("%10.2f", -$cust_main->balance ) ];
    }
  }

  if ( $multisection ) {
    if ($conf->exists('svc_phone_sections')) {
      my $total;
      $total->{'total_item'} = &$embolden_function($self->balance_due_msg);
      $total->{'total_amount'} =
        &$embolden_function(
          $other_money_char. sprintf('%.2f', $self->owed + $pr_total)
        );
      my $last_section = pop @sections;
      $last_section->{'posttotal'} = $total->{'total_item'}. ' '.
                                     $total->{'total_amount'};
      push @sections, $last_section;
    }
    push @sections, @$late_sections
      if $unsquelched;
  }

  # make a discounts-available section, even without multisection
  if ( $conf->exists('discount-show_available') 
       and my @discounts_avail = $self->_items_discounts_avail ) {
    my $discount_section = {
      'description' => $self->mt('Discounts Available'),
      'subtotal'    => '',
      'no_subtotal' => 1,
    };

    push @sections, $discount_section;
    push @detail_items, map { +{
        'ref'         => '', #should this be something else?
        'section'     => $discount_section,
        'description' => &$escape_function( $_->{description} ),
        'amount'      => $money_char . &$escape_function( $_->{amount} ),
        'ext_description' => [ &$escape_function($_->{ext_description}) || () ],
    } } @discounts_avail;
  }

  # debugging hook: call this with 'diag' => 1 to just get a hash of
  # the invoice variables
  return \%invoice_data if ( $params{'diag'} );

  # All sections and items are built; now fill in templates.
  my @includelist = ();
  push @includelist, 'summary' if $summarypage;
  foreach my $include ( @includelist ) {

    my $inc_file = $conf->key_orbase("invoice_${format}$include", $template);
    my @inc_src;

    if ( length( $conf->config($inc_file, $agentnum) ) ) {

      @inc_src = $conf->config($inc_file, $agentnum);

    } else {

      $inc_file = $conf->key_orbase("invoice_latex$include", $template);

      my $convert_map = $convert_maps{$format}{$include};

      @inc_src = map { s/\[\@--/$delimiters{$format}[0]/g;
                       s/--\@\]/$delimiters{$format}[1]/g;
                       $_;
                     } 
                 &$convert_map( $conf->config($inc_file, $agentnum) );

    }

    my $inc_tt = new Text::Template (
      TYPE       => 'ARRAY',
      SOURCE     => [ map "$_\n", @inc_src ],
      DELIMITERS => $delimiters{$format},
    ) or die "Can't create new Text::Template object: $Text::Template::ERROR";

    unless ( $inc_tt->compile() ) {
      my $error = "Can't compile $inc_file template: $Text::Template::ERROR\n";
      warn $error. "Template:\n". join('', map "$_\n", @inc_src);
      die $error;
    }

    $invoice_data{$include} = $inc_tt->fill_in( HASH => \%invoice_data );

    $invoice_data{$include} =~ s/\n+$//
      if ($format eq 'latex');
  }

  $invoice_lines = 0;
  my $wasfunc = 0;
  foreach ( grep /invoice_lines\(\d*\)/, @invoice_template ) { #kludgy
    /invoice_lines\((\d*)\)/;
    $invoice_lines += $1 || scalar(@buf);
    $wasfunc=1;
  }
  die "no invoice_lines() functions in template?"
    if ( $format eq 'template' && !$wasfunc );

  if ($format eq 'template') {

    if ( $invoice_lines ) {
      $invoice_data{'total_pages'} = int( scalar(@buf) / $invoice_lines );
      $invoice_data{'total_pages'}++
        if scalar(@buf) % $invoice_lines;
    }

    #setup subroutine for the template
    $invoice_data{invoice_lines} = sub {
      my $lines = shift || scalar(@buf);
      map { 
        scalar(@buf)
          ? shift @buf
          : [ '', '' ];
      }
      ( 1 .. $lines );
    };

    my $lines;
    my @collect;
    while (@buf) {
      push @collect, split("\n",
        $text_template->fill_in( HASH => \%invoice_data )
      );
      $invoice_data{'page'}++;
    }
    map "$_\n", @collect;
  }else{
    # this is where we actually create the invoice
    warn "filling in template for invoice ". $self->invnum. "\n"
      if $DEBUG;
    warn join("\n", map " $_ => ". $invoice_data{$_}, keys %invoice_data). "\n"
      if $DEBUG > 1;

    $text_template->fill_in(HASH => \%invoice_data);
  }
}

# helper routine for generating date ranges
sub _prior_month30s {
  my $self = shift;
  my @ranges = (
   [ 1,       2592000 ], # 0-30 days ago
   [ 2592000, 5184000 ], # 30-60 days ago
   [ 5184000, 7776000 ], # 60-90 days ago
   [ 7776000, 0       ], # 90+   days ago
  );

  map { [ $_->[0] ? $self->_date - $_->[0] - 1 : '',
          $_->[1] ? $self->_date - $_->[1] - 1 : '',
      ] }
  @ranges;
}

=item print_ps HASHREF | [ TIME [ , TEMPLATE ] ]

Returns an postscript invoice, as a scalar.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_ps {
  my $self = shift;

  my ($file, $logofile, $barcodefile) = $self->print_latex(@_);
  my $ps = generate_ps($file);
  unlink($logofile);
  unlink($barcodefile) if $barcodefile;

  $ps;
}

=item print_pdf HASHREF | [ TIME [ , TEMPLATE ] ]

Returns an PDF invoice, as a scalar.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_pdf {
  my $self = shift;

  my ($file, $logofile, $barcodefile) = $self->print_latex(@_);
  my $pdf = generate_pdf($file);
  unlink($logofile);
  unlink($barcodefile) if $barcodefile;

  $pdf;
}

=item print_html HASHREF | [ TIME [ , TEMPLATE [ , CID ] ] ]

Returns an HTML invoice, as a scalar.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

I<cid> is a MIME Content-ID used to create a "cid:" URL for the logo image, used
when emailing the invoice as part of a multipart/related MIME email.

=cut

sub print_html {
  my $self = shift;
  my %params;
  if ( ref($_[0]) ) {
    %params = %{ shift() }; 
  }else{
    $params{'time'} = shift;
    $params{'template'} = shift;
    $params{'cid'} = shift;
  }

  $params{'format'} = 'html';
  
  $self->print_generic( %params );
}

# quick subroutine for print_latex
#
# There are ten characters that LaTeX treats as special characters, which
# means that they do not simply typeset themselves: 
#      # $ % & ~ _ ^ \ { }
#
# TeX ignores blanks following an escaped character; if you want a blank (as
# in "10% of ..."), you have to "escape" the blank as well ("10\%\ of ..."). 

sub _latex_escape {
  my $value = shift;
  $value =~ s/([#\$%&~_\^{}])( )?/"\\$1". ( ( defined($2) && length($2) ) ? "\\$2" : '' )/ge;
  $value =~ s/([<>])/\$$1\$/g;
  $value;
}

sub _html_escape {
  my $value = shift;
  encode_entities($value);
  $value;
}

sub _html_escape_nbsp {
  my $value = _html_escape(shift);
  $value =~ s/ +/&nbsp;/g;
  $value;
}

#utility methods for print_*

sub _translate_old_latex_format {
  warn "_translate_old_latex_format called\n"
    if $DEBUG; 

  my @template = ();
  while ( @_ ) {
    my $line = shift;
  
    if ( $line =~ /^%%Detail\s*$/ ) {
  
      push @template, q![@--!,
                      q!  foreach my $_tr_line (@detail_items) {!,
                      q!    if ( scalar ($_tr_item->{'ext_description'} ) ) {!,
                      q!      $_tr_line->{'description'} .= !, 
                      q!        "\\tabularnewline\n~~".!,
                      q!        join( "\\tabularnewline\n~~",!,
                      q!          @{$_tr_line->{'ext_description'}}!,
                      q!        );!,
                      q!    }!;

      while ( ( my $line_item_line = shift )
              !~ /^%%EndDetail\s*$/                            ) {
        $line_item_line =~ s/'/\\'/g;    # nice LTS
        $line_item_line =~ s/\\/\\\\/g;  # escape quotes and backslashes
        $line_item_line =~ s/\$(\w+)/'. \$_tr_line->{$1}. '/g;
        push @template, "    \$OUT .= '$line_item_line';";
      }

      push @template, '}',
                      '--@]';
      #' doh, gvim
    } elsif ( $line =~ /^%%TotalDetails\s*$/ ) {

      push @template, '[@--',
                      '  foreach my $_tr_line (@total_items) {';

      while ( ( my $total_item_line = shift )
              !~ /^%%EndTotalDetails\s*$/                      ) {
        $total_item_line =~ s/'/\\'/g;    # nice LTS
        $total_item_line =~ s/\\/\\\\/g;  # escape quotes and backslashes
        $total_item_line =~ s/\$(\w+)/'. \$_tr_line->{$1}. '/g;
        push @template, "    \$OUT .= '$total_item_line';";
      }

      push @template, '}',
                      '--@]';

    } else {
      $line =~ s/\$(\w+)/[\@-- \$$1 --\@]/g;
      push @template, $line;  
    }
  
  }

  if ($DEBUG) {
    warn "$_\n" foreach @template;
  }

  (@template);
}

sub terms {
  my $self = shift;
  my $conf = $self->conf;

  #check for an invoice-specific override
  return $self->invoice_terms if $self->invoice_terms;
  
  #check for a customer- specific override
  my $cust_main = $self->cust_main;
  return $cust_main->invoice_terms if $cust_main->invoice_terms;

  #use configured default
  $conf->config('invoice_default_terms') || '';
}

sub due_date {
  my $self = shift;
  my $duedate = '';
  if ( $self->terms =~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = $self->_date() + ( $1 * 86400 );
  }
  $duedate;
}

sub due_date2str {
  my $self = shift;
  $self->due_date ? $self->time2str_local(shift, $self->due_date) : '';
}

sub balance_due_msg {
  my $self = shift;
  my $msg = $self->mt('Balance Due');
  return $msg unless $self->terms;
  if ( $self->due_date ) {
    $msg .= ' - ' . $self->mt('Please pay by'). ' '.
      $self->due_date2str('short');
  } elsif ( $self->terms ) {
    $msg .= ' - '. $self->terms;
  }
  $msg;
}

sub balance_due_date {
  my $self = shift;
  my $conf = $self->conf;
  my $duedate = '';
  if (    $conf->exists('invoice_default_terms') 
       && $conf->config('invoice_default_terms')=~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = $self->time2str_local('rdate', $self->_date + ($1*86400) );
  }
  $duedate;
}

sub credit_balance_msg { 
  my $self = shift;
  $self->mt('Credit Balance Remaining')
}

=item invnum_date_pretty

Returns a string with the invoice number and date, for example:
"Invoice #54 (3/20/2008)"

=cut

sub invnum_date_pretty {
  my $self = shift;
  $self->mt('Invoice #'). $self->invnum. ' ('. $self->_date_pretty. ')';
}

=item _date_pretty

Returns a string with the date, for example: "3/20/2008"

=cut

sub _date_pretty {
  my $self = shift;
  $self->time2str_local('short', $self->_date);
}

=item _items_sections LATE SUMMARYPAGE ESCAPE EXTRA_SECTIONS FORMAT

Generate section information for all items appearing on this invoice.
This will only be called for multi-section invoices.

For each line item (L<FS::cust_bill_pkg> record), this will fetch all 
related display records (L<FS::cust_bill_pkg_display>) and organize 
them into two groups ("early" and "late" according to whether they come 
before or after the total), then into sections.  A subtotal is calculated 
for each section.

Section descriptions are returned in sort weight order.  Each consists 
of a hash containing:

description: the package category name, escaped
subtotal: the total charges in that section
tax_section: a flag indicating that the section contains only tax charges
summarized: same as tax_section, for some reason
sort_weight: the package category's sort weight

If 'condense' is set on the display record, it also contains everything 
returned from C<_condense_section()>, i.e. C<_condensed_foo_generator>
coderefs to generate parts of the invoice.  This is not advised.

Arguments:

LATE: an arrayref to push the "late" section hashes onto.  The "early"
group is simply returned from the method.

SUMMARYPAGE: a flag indicating whether this is a summary-format invoice.
Turning this on has the following effects:
- Ignores display items with the 'summary' flag.
- Combines all items into the "early" group.
- Creates sections for all non-disabled package categories, even if they 
have no charges on this invoice, as well as a section with no name.

ESCAPE: an escape function to use for section titles.

EXTRA_SECTIONS: an arrayref of additional sections to return after the 
sorted list.  If there are any of these, section subtotals exclude 
usage charges.

FORMAT: 'latex', 'html', or 'template' (i.e. text).  Not used, but 
passed through to C<_condense_section()>.

=cut

use vars qw(%pkg_category_cache);
sub _items_sections {
  my $self = shift;
  my $late = shift;
  my $summarypage = shift;
  my $escape = shift;
  my $extra_sections = shift;
  my $format = shift;

  my %subtotal = ();
  my %late_subtotal = ();
  my %not_tax = ();

  foreach my $cust_bill_pkg ( $self->cust_bill_pkg )
  {

      my $usage = $cust_bill_pkg->usage;

      foreach my $display ($cust_bill_pkg->cust_bill_pkg_display) {
        next if ( $display->summary && $summarypage );

        my $section = $display->section;
        my $type    = $display->type;

        $not_tax{$section} = 1
          unless $cust_bill_pkg->pkgnum == 0;

        if ( $display->post_total && !$summarypage ) {
          if (! $type || $type eq 'S') {
            $late_subtotal{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          }

          if (! $type) {
            $late_subtotal{$section} += $cust_bill_pkg->recur
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }

          if ($type && $type eq 'R') {
            $late_subtotal{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }
          
          if ($type && $type eq 'U') {
            $late_subtotal{$section} += $usage
              unless scalar(@$extra_sections);
          }

        } else {

          next if $cust_bill_pkg->pkgnum == 0 && ! $section;

          if (! $type || $type eq 'S') {
            $subtotal{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          }

          if (! $type) {
            $subtotal{$section} += $cust_bill_pkg->recur
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }

          if ($type && $type eq 'R') {
            $subtotal{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }
          
          if ($type && $type eq 'U') {
            $subtotal{$section} += $usage
              unless scalar(@$extra_sections);
          }

        }

      }

  }

  %pkg_category_cache = ();

  push @$late, map { { 'description' => &{$escape}($_),
                       'subtotal'    => $late_subtotal{$_},
                       'post_total'  => 1,
                       'sort_weight' => ( _pkg_category($_)
                                            ? _pkg_category($_)->weight
                                            : 0
                                       ),
                       ((_pkg_category($_) && _pkg_category($_)->condense)
                                           ? $self->_condense_section($format)
                                           : ()
                       ),
                   } }
                 sort _sectionsort keys %late_subtotal;

  my @sections;
  if ( $summarypage ) {
    @sections = grep { exists($subtotal{$_}) || ! _pkg_category($_)->disabled }
                map { $_->categoryname } qsearch('pkg_category', {});
    push @sections, '' if exists($subtotal{''});
  } else {
    @sections = keys %subtotal;
  }

  my @early = map { { 'description' => &{$escape}($_),
                      'subtotal'    => $subtotal{$_},
                      'summarized'  => $not_tax{$_} ? '' : 'Y',
                      'tax_section' => $not_tax{$_} ? '' : 'Y',
                      'sort_weight' => ( _pkg_category($_)
                                           ? _pkg_category($_)->weight
                                           : 0
                                       ),
                       ((_pkg_category($_) && _pkg_category($_)->condense)
                                           ? $self->_condense_section($format)
                                           : ()
                       ),
                    }
                  } @sections;
  push @early, @$extra_sections if $extra_sections;

  sort { $a->{sort_weight} <=> $b->{sort_weight} } @early;

}

#helper subs for above

sub _sectionsort {
  _pkg_category($a)->weight <=> _pkg_category($b)->weight;
}

sub _pkg_category {
  my $categoryname = shift;
  $pkg_category_cache{$categoryname} ||=
    qsearchs( 'pkg_category', { 'categoryname' => $categoryname } );
}

my %condensed_format = (
  'label' => [ qw( Description Qty Amount ) ],
  'fields' => [
                sub { shift->{description} },
                sub { shift->{quantity} },
                sub { my($href, %opt) = @_;
                      ($opt{dollar} || ''). $href->{amount};
                    },
              ],
  'align'  => [ qw( l r r ) ],
  'span'   => [ qw( 5 1 1 ) ],            # unitprices?
  'width'  => [ qw( 10.7cm 1.4cm 1.6cm ) ],   # don't like this
);

sub _condense_section {
  my ( $self, $format ) = ( shift, shift );
  ( 'condensed' => 1,
    map { my $method = "_condensed_$_"; $_ => $self->$method($format) }
      qw( description_generator
          header_generator
          total_generator
          total_line_generator
        )
  );
}

sub _condensed_generator_defaults {
  my ( $self, $format ) = ( shift, shift );
  return ( \%condensed_format, ' ', ' ', ' ', sub { shift } );
}

my %html_align = (
  'c' => 'center',
  'l' => 'left',
  'r' => 'right',
);

sub _condensed_header_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);

  if ($format eq 'latex') {
    $prefix = "\\hline\n\\rule{0pt}{2.5ex}\n\\makebox[1.4cm]{}&\n";
    $suffix = "\\\\\n\\hline";
    $separator = "&\n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
  } elsif ( $format eq 'html' ) {
    $prefix = '<th></th>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<th align="$html_align{$a}">$d</th>!;
      };
  }

  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( map { $f->{$_}->[$i] } qw(label align span width) );
    }

    $prefix. join($separator, @result). $suffix;
  };

}

sub _condensed_description_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);

  my $money_char = '$';
  if ($format eq 'latex') {
    $prefix = "\\hline\n\\multicolumn{1}{c}{\\rule{0pt}{2.5ex}~} &\n";
    $suffix = '\\\\';
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
    $money_char = '\\dollar';
  }elsif ( $format eq 'html' ) {
    $prefix = '"><td align="center"></td>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}">$d</td>!;
      };
    #$money_char = $conf->config('money_char') || '$';
    $money_char = '';  # this is madness
  }

  sub {
    #my @args = @_;
    my $href = shift;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      my $dollar = '';
      $dollar = $money_char if $i == scalar(@{$f->{label}})-1;
      push @result,
        &{$column}( &{$f->{fields}->[$i]}($href, 'dollar' => $dollar),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

sub _condensed_total_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }


  sub {
    my @args = @_;
    my @result = ();

    #  my $r = &{$f->{fields}->[$i]}(@args);
    #  $r .= ' Total' unless $i;

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args). ($i ? '' : ' Total'),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

=item total_line_generator FORMAT

Returns a coderef used for generation of invoice total line items for this
usage_class.  FORMAT is either html or latex

=cut

# should not be used: will have issues with hash element names (description vs
# total_item and amount vs total_amount -- another array of functions?

sub _condensed_total_line_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }


  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

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

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 50;

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

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 50;

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

sub _items { # seems to be unused
  my $self = shift;

  #my @display = scalar(@_)
  #              ? @_
  #              : qw( _items_previous _items_pkg );
  #              #: qw( _items_pkg );
  #              #: qw( _items_previous _items_pkg _items_tax _items_credits _items_payments );
  my @display = qw( _items_previous _items_pkg );

  my @b = ();
  foreach my $display ( @display ) {
    push @b, $self->$display(@_);
  }
  @b;
}

sub _items_previous {
  my $self = shift;
  my $conf = $self->conf;
  my $cust_main = $self->cust_main;
  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
  my @b = ();
  foreach ( @pr_cust_bill ) {
    my $date = $conf->exists('invoice_show_prior_due_date')
               ? 'due '. $_->due_date2str('short')
               : $self->time2str_local('short', $_->_date);
    push @b, {
      'description' => $self->mt('Previous Balance, Invoice #'). $_->invnum. " ($date)",
      #'pkgpart'     => 'N/A',
      'pkgnum'      => 'N/A',
      'amount'      => sprintf("%.2f", $_->owed),
    };
  }
  @b;

  #{
  #    'description'     => 'Previous Balance',
  #    #'pkgpart'         => 'N/A',
  #    'pkgnum'          => 'N/A',
  #    'amount'          => sprintf("%10.2f", $pr_total ),
  #    'ext_description' => [ map {
  #                                 "Invoice ". $_->invnum.
  #                                 " (". time2str("%x",$_->_date). ") ".
  #                                 sprintf("%10.2f", $_->owed)
  #                         } @pr_cust_bill ],

  #};
}

=item _items_pkg [ OPTIONS ]

Return line item hashes for each package item on this invoice. Nearly 
equivalent to 

$self->_items_cust_bill_pkg([ $self->cust_bill_pkg ])

The only OPTIONS accepted is 'section', which may point to a hashref 
with a key named 'condensed', which may have a true value.  If it 
does, this method tries to merge identical items into items with 
'quantity' equal to the number of items (not the sum of their 
separate quantities, for some reason).

=cut

sub _items_pkg {
  my $self = shift;
  my %options = @_;

  warn "$me _items_pkg searching for all package line items\n"
    if $DEBUG > 1;

  my @cust_bill_pkg = grep { $_->pkgnum } $self->cust_bill_pkg;

  warn "$me _items_pkg filtering line items\n"
    if $DEBUG > 1;
  my @items = $self->_items_cust_bill_pkg(\@cust_bill_pkg, @_);

  if ($options{section} && $options{section}->{condensed}) {

    warn "$me _items_pkg condensing section\n"
      if $DEBUG > 1;

    my %itemshash = ();
    local $Storable::canonical = 1;
    foreach ( @items ) {
      my $item = { %$_ };
      delete $item->{ref};
      delete $item->{ext_description};
      my $key = freeze($item);
      $itemshash{$key} ||= 0;
      $itemshash{$key} ++; # += $item->{quantity};
    }
    @items = sort { $a->{description} cmp $b->{description} }
             map { my $i = thaw($_);
                   $i->{quantity} = $itemshash{$_};
                   $i->{amount} =
                     sprintf( "%.2f", $i->{quantity} * $i->{amount} );#unit_amount
                   $i;
                 }
             keys %itemshash;
  }

  warn "$me _items_pkg returning ". scalar(@items). " items\n"
    if $DEBUG > 1;

  @items;
}

sub _taxsort {
  return 0 unless $a->itemdesc cmp $b->itemdesc;
  return -1 if $b->itemdesc eq 'Tax';
  return 1 if $a->itemdesc eq 'Tax';
  return -1 if $b->itemdesc eq 'Other surcharges';
  return 1 if $a->itemdesc eq 'Other surcharges';
  $a->itemdesc cmp $b->itemdesc;
}

sub _items_tax {
  my $self = shift;
  my @cust_bill_pkg = sort _taxsort grep { ! $_->pkgnum } $self->cust_bill_pkg;
  $self->_items_cust_bill_pkg(\@cust_bill_pkg, @_);
}

=item _items_cust_bill_pkg CUST_BILL_PKGS OPTIONS

Takes an arrayref of L<FS::cust_bill_pkg> objects, and returns a
list of hashrefs describing the line items they generate on the invoice.

OPTIONS may include:

format: the invoice format.

escape_function: the function used to escape strings.

DEPRECATED? (expensive, mostly unused?)
format_function: the function used to format CDRs.

section: a hashref containing 'description'; if this is present, 
cust_bill_pkg_display records not belonging to this section are 
ignored.

multisection: a flag indicating that this is a multisection invoice,
which does something complicated.

multilocation: a flag to display the location label for the package.

Returns a list of hashrefs, each of which may contain:

pkgnum, description, amount, unit_amount, quantity, _is_setup, and 
ext_description, which is an arrayref of detail lines to show below 
the package line.

=cut

sub _items_cust_bill_pkg {
  my $self = shift;
  my $conf = $self->conf;
  my $cust_bill_pkgs = shift;
  my %opt = @_;

  my $format = $opt{format} || '';
  my $escape_function = $opt{escape_function} || sub { shift };
  my $format_function = $opt{format_function} || '';
  my $no_usage = $opt{no_usage} || '';
  my $unsquelched = $opt{unsquelched} || ''; #unused
  my $section = $opt{section}->{description} if $opt{section};
  my $summary_page = $opt{summary_page} || ''; #unused
  my $multilocation = $opt{multilocation} || '';
  my $multisection = $opt{multisection} || '';
  my $discount_show_always = 0;

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 50;

  my $cust_main = $self->cust_main;#for per-agent cust_bill-line_item-ate_style

  my @b = ();
  my ($s, $r, $u) = ( undef, undef, undef );
  foreach my $cust_bill_pkg ( @$cust_bill_pkgs )
  {

    foreach ( $s, $r, ($opt{skip_usage} ? () : $u ) ) {
      if ( $_ && !$cust_bill_pkg->hidden ) {
        $_->{amount}      = sprintf( "%.2f", $_->{amount} ),
        $_->{amount}      =~ s/^\-0\.00$/0.00/;
        $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} ),
        push @b, { %$_ }
          if $_->{amount} != 0
          || $discount_show_always
          || ( ! $_->{_is_setup} && $_->{recur_show_zero} )
          || (   $_->{_is_setup} && $_->{setup_show_zero} )
        ;
        $_ = undef;
      }
    }

    my @cust_bill_pkg_display = $cust_bill_pkg->cust_bill_pkg_display;

    warn "$me _items_cust_bill_pkg considering cust_bill_pkg ".
         $cust_bill_pkg->billpkgnum. ", pkgnum ". $cust_bill_pkg->pkgnum. "\n"
      if $DEBUG > 1;

    foreach my $display ( grep { defined($section)
                                 ? $_->section eq $section
                                 : 1
                               }
                          #grep { !$_->summary || !$summary_page } # bunk!
                          grep { !$_->summary || $multisection }
                          @cust_bill_pkg_display
                        )
    {

      warn "$me _items_cust_bill_pkg considering cust_bill_pkg_display ".
           $display->billpkgdisplaynum. "\n"
        if $DEBUG > 1;

      my $type = $display->type;

      my $desc = $cust_bill_pkg->desc;
      $desc = substr($desc, 0, $maxlength). '...'
        if $format eq 'latex' && length($desc) > $maxlength;

      my %details_opt = ( 'format'          => $format,
                          'escape_function' => $escape_function,
                          'format_function' => $format_function,
                          'no_usage'        => $opt{'no_usage'},
                        );

      if ( $cust_bill_pkg->pkgnum > 0 ) {

        warn "$me _items_cust_bill_pkg cust_bill_pkg is non-tax\n"
          if $DEBUG > 1;
 
        my $cust_pkg = $cust_bill_pkg->cust_pkg;

        # which pkgpart to show for display purposes?
        my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;

        # start/end dates for invoice formats that do nonstandard 
        # things with them
        my %item_dates = ();
        %item_dates = map { $_ => $cust_bill_pkg->$_ } ('sdate', 'edate')
          unless $cust_pkg->part_pkg->option('disable_line_item_date_ranges',1);

        if (    (!$type || $type eq 'S')
             && (    $cust_bill_pkg->setup != 0
                  || $cust_bill_pkg->setup_show_zero
                )
           )
         {

          warn "$me _items_cust_bill_pkg adding setup\n"
            if $DEBUG > 1;

          my $description = $desc;
          $description .= ' Setup'
            if $cust_bill_pkg->recur != 0
            || $discount_show_always
            || $cust_bill_pkg->recur_show_zero;

          my @d = ();
          my $svc_label;
          unless ( $cust_pkg->part_pkg->hide_svc_detail
                || $cust_bill_pkg->hidden )
          {

            my @svc_labels = map &{$escape_function}($_),
                        $cust_pkg->h_labels_short($self->_date, undef, 'I');
            push @d, @svc_labels
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services
            $svc_label = $svc_labels[0];

            if ( $multilocation ) {
              my $loc = $cust_pkg->location_label;
              $loc = substr($loc, 0, $maxlength). '...'
                if $format eq 'latex' && length($loc) > $maxlength;
              push @d, &{$escape_function}($loc);
            }

          } #unless hiding service details

          push @d, $cust_bill_pkg->details(%details_opt)
            if $cust_bill_pkg->recur == 0;

          if ( $cust_bill_pkg->hidden ) {
            $s->{amount}      += $cust_bill_pkg->setup;
            $s->{unit_amount} += $cust_bill_pkg->unitsetup;
            push @{ $s->{ext_description} }, @d;
          } else {
            $s = {
              _is_setup       => 1,
              description     => $description,
              pkgpart         => $pkgpart,
              pkgnum          => $cust_bill_pkg->pkgnum,
              amount          => $cust_bill_pkg->setup,
              setup_show_zero => $cust_bill_pkg->setup_show_zero,
              unit_amount     => $cust_bill_pkg->unitsetup,
              quantity        => $cust_bill_pkg->quantity,
              ext_description => \@d,
              svc_label       => ($svc_label || ''),
            };
          };

        }

        if (    ( !$type || $type eq 'R' || $type eq 'U' )
             && (
                     $cust_bill_pkg->recur != 0
                  || $cust_bill_pkg->setup == 0
                  || $discount_show_always
                  || $cust_bill_pkg->recur_show_zero
                )
           )
        {

          warn "$me _items_cust_bill_pkg adding recur/usage\n"
            if $DEBUG > 1;

          my $is_summary = $display->summary;
          my $description = ($is_summary && $type && $type eq 'U')
                            ? "Usage charges" : $desc;

          my $part_pkg = $cust_pkg->part_pkg;

          #pry be a bit more efficient to look some of this conf stuff up
          # outside the loop
          unless (
            $conf->exists('disable_line_item_date_ranges')
              || $part_pkg->option('disable_line_item_date_ranges',1)
              || ! $cust_bill_pkg->sdate
              || ! $cust_bill_pkg->edate
          ) {
            my $time_period;
            my $date_style = '';                                               
            $date_style = $conf->config( 'cust_bill-line_item-date_style-non_monthly',
                                         $cust_main->agentnum                  
                                       )                                       
              if $part_pkg && $part_pkg->freq !~ /^1m?$/;                      
            $date_style ||= $conf->config( 'cust_bill-line_item-date_style',   
                                            $cust_main->agentnum
                                          );
            if ( defined($date_style) && $date_style eq 'month_of' ) {
              $time_period = $self->mt('The month of [_1]',
                               $self->time2str_local('%B', $cust_bill_pkg->sdate)
                             );
            } elsif ( defined($date_style) && $date_style eq 'X_month' ) {
              my $desc = $conf->config( 'cust_bill-line_item-date_description',
                                         $cust_main->agentnum
                                      );
              $desc .= ' ' unless $desc =~ /\s$/;
              $time_period = $desc. $self->time2str_local('%B', $cust_bill_pkg->sdate);
            } else {
              $time_period =      $self->time2str_local('short', $cust_bill_pkg->sdate).
                           " - ". $self->time2str_local('short', $cust_bill_pkg->edate);
            }
            $description .= " ($time_period)";
          }

          my @d = ();
          my @seconds = (); # for display of usage info
          my $svc_label = '';

          #at least until cust_bill_pkg has "past" ranges in addition to
          #the "future" sdate/edate ones... see #3032
          my @dates = ( $self->_date );
          my $prev = $cust_bill_pkg->previous_cust_bill_pkg;
          push @dates, $prev->sdate if $prev;
          push @dates, undef if !$prev;

          unless ( $cust_pkg->part_pkg->hide_svc_detail
                || $cust_bill_pkg->itemdesc
                || $cust_bill_pkg->hidden
                || $is_summary && $type && $type eq 'U' )
          {

            warn "$me _items_cust_bill_pkg adding service details\n"
              if $DEBUG > 1;

            my @svc_labels = map &{$escape_function}($_),
                        $cust_pkg->h_labels_short(@dates, 'I');
            push @d, @svc_labels
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services
            $svc_label = $svc_labels[0];

            warn "$me _items_cust_bill_pkg done adding service details\n"
              if $DEBUG > 1;

            if ( $multilocation ) {
              my $loc = $cust_pkg->location_label;
              $loc = substr($loc, 0, $maxlength). '...'
                if $format eq 'latex' && length($loc) > $maxlength;
              push @d, &{$escape_function}($loc);
            }

            # Display of seconds_since_sqlradacct:
            # On the invoice, when processing @detail_items, look for a field
            # named 'seconds'.  This will contain total seconds for each 
            # service, in the same order as @ext_description.  For services 
            # that don't support this it will show undef.
            if ( $conf->exists('svc_acct-usage_seconds') 
                 and ! $cust_bill_pkg->pkgpart_override ) {
              foreach my $cust_svc ( 
                  $cust_pkg->h_cust_svc(@dates, 'I') 
                ) {

                # eval because not having any part_export_usage exports 
                # is a fatal error, last_bill/_date because that's how 
                # sqlradius_hour billing does it
                my $sec = eval {
                  $cust_svc->seconds_since_sqlradacct($dates[1] || 0, $dates[0]);
                };
                push @seconds, $sec;
              }
            } #if svc_acct-usage_seconds

          }

          unless ( $is_summary ) {
            warn "$me _items_cust_bill_pkg adding details\n"
              if $DEBUG > 1;

            #instead of omitting details entirely in this case (unwanted side
            # effects), just omit CDRs
            $details_opt{'no_usage'} = 1
              if $type && $type eq 'R';

            push @d, $cust_bill_pkg->details(%details_opt);
          }

          warn "$me _items_cust_bill_pkg calculating amount\n"
            if $DEBUG > 1;
  
          my $amount = 0;
          if (!$type) {
            $amount = $cust_bill_pkg->recur;
          } elsif ($type eq 'R') {
            $amount = $cust_bill_pkg->recur - $cust_bill_pkg->usage;
          } elsif ($type eq 'U') {
            $amount = $cust_bill_pkg->usage;
          }
  
          if ( !$type || $type eq 'R' ) {

            warn "$me _items_cust_bill_pkg adding recur\n"
              if $DEBUG > 1;

            if ( $cust_bill_pkg->hidden ) {
              $r->{amount}      += $amount;
              $r->{unit_amount} += $cust_bill_pkg->unitrecur;
              push @{ $r->{ext_description} }, @d;
            } else {
              $r = {
                description     => $description,
                pkgpart         => $pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                unit_amount     => $cust_bill_pkg->unitrecur,
                quantity        => $cust_bill_pkg->quantity,
                %item_dates,
                ext_description => \@d,
                svc_label       => ($svc_label || ''),
              };
              $r->{'seconds'} = \@seconds if grep {defined $_} @seconds;
            }

          } else {  # $type eq 'U'

            warn "$me _items_cust_bill_pkg adding usage\n"
              if $DEBUG > 1;

            if ( $cust_bill_pkg->hidden ) {
              $u->{amount}      += $amount;
              $u->{unit_amount} += $cust_bill_pkg->unitrecur;
              push @{ $u->{ext_description} }, @d;
            } else {
              $u = {
                description     => $description,
                pkgpart         => $pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                unit_amount     => $cust_bill_pkg->unitrecur,
                quantity        => $cust_bill_pkg->quantity,
                %item_dates,
                ext_description => \@d,
              };
            }
          }

        } # recurring or usage with recurring charge

      } else { #pkgnum tax or one-shot line item (??)

        warn "$me _items_cust_bill_pkg cust_bill_pkg is tax\n"
          if $DEBUG > 1;

        if ( $cust_bill_pkg->setup != 0 ) {
          push @b, {
            'description' => $desc,
            'amount'      => sprintf("%.2f", $cust_bill_pkg->setup),
          };
        }
        if ( $cust_bill_pkg->recur != 0 ) {
          push @b, {
            'description' => "$desc (".
                             $self->time2str_local('short', $cust_bill_pkg->sdate). ' - '.
                             $self->time2str_local('short', $cust_bill_pkg->edate). ')',
            'amount'      => sprintf("%.2f", $cust_bill_pkg->recur),
          };
        }

      }

    }

    $discount_show_always = ($cust_bill_pkg->cust_bill_pkg_discount
                                && $conf->exists('discount-show-always'));

  }

  foreach ( $s, $r, ($opt{skip_usage} ? () : $u ) ) {
    if ( $_  ) {
      $_->{amount}      = sprintf( "%.2f", $_->{amount} ),
      $_->{amount}      =~ s/^\-0\.00$/0.00/;
      $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} ),
      push @b, { %$_ }
        if $_->{amount} != 0
        || $discount_show_always
        || ( ! $_->{_is_setup} && $_->{recur_show_zero} )
        || (   $_->{_is_setup} && $_->{setup_show_zero} )
    }
  }

  warn "$me _items_cust_bill_pkg done considering cust_bill_pkgs\n"
    if $DEBUG > 1;

  @b;

}

sub _items_credits {
  my( $self, %opt ) = @_;
  my $trim_len = $opt{'trim_len'} || 60;

  my @b;
  #credits
  my @objects;
  if ( $self->conf->exists('previous_balance-payments_since') ) {
    if ( $opt{'template'} eq 'statement' ) {
      # then the current bill is a "statement" (i.e. an invoice sent as
      # a payment receipt)
      # and in that case we want to see payments on or after THIS invoice
      @objects = qsearch('cust_credit', {
          'custnum' => $self->custnum,
          '_date'   => {op => '>=', value => $self->_date},
      });
    } else {
      my $date = 0;
      $date = $self->previous_bill->_date if $self->previous_bill;
      @objects = qsearch('cust_credit', {
          'custnum' => $self->custnum,
          '_date'   => {op => '>=', value => $date},
      });
    }
  } else {
    @objects = $self->cust_credited;
  }

  foreach my $obj ( @objects ) {
    my $cust_credit = $obj->isa('FS::cust_credit') ? $obj : $obj->cust_credit;

    my $reason = substr($cust_credit->reason, 0, $trim_len);
    $reason .= '...' if length($reason) < length($cust_credit->reason);
    $reason = " ($reason) " if $reason;

    push @b, {
      #'description' => 'Credit ref\#'. $_->crednum.
      #                 " (". time2str("%x",$_->cust_credit->_date) .")".
      #                 $reason,
      'description' => $self->mt('Credit applied').' '.
                       $self->time2str_local('short', $obj->_date). $reason,
      'amount'      => sprintf("%.2f",$obj->amount),
    };
  }

  @b;

}

sub _items_payments {
  my $self = shift;
  my %opt = @_;

  my @b;
  my $detailed = $self->conf->exists('invoice_payment_details');
  my @objects;
  if ( $self->conf->exists('previous_balance-payments_since') ) {
    # then show payments dated on/after the previous bill...
    if ( $opt{'template'} eq 'statement' ) {
      # then the current bill is a "statement" (i.e. an invoice sent as
      # a payment receipt)
      # and in that case we want to see payments on or after THIS invoice
      @objects = qsearch('cust_pay', {
          'custnum' => $self->custnum,
          '_date'   => {op => '>=', value => $self->_date},
      });
    } else {
      # the normal case: payments on or after the previous invoice
      my $date = 0;
      $date = $self->previous_bill->_date if $self->previous_bill;
      @objects = qsearch('cust_pay', {
        'custnum' => $self->custnum,
        '_date'   => {op => '>=', value => $date},
      });
      # and before the current bill...
      @objects = grep { $_->_date < $self->_date } @objects;
    }
  } else {
    @objects = $self->cust_bill_pay;
  }

  foreach my $obj (@objects) {
    my $cust_pay = $obj->isa('FS::cust_pay') ? $obj : $obj->cust_pay;
    my $desc = $self->mt('Payment received').' '.
               $self->time2str_local('short', $cust_pay->_date );
    $desc .= $self->mt(' via ') .
             $cust_pay->payby_payinfo_pretty( $self->cust_main->locale )
      if $detailed;

    push @b, {
      'description' => $desc,
      'amount'      => sprintf("%.2f", $obj->amount )
    };
  }

  @b;

}

=item _items_discounts_avail

Returns an array of line item hashrefs representing available term discounts
for this invoice.  This makes the same assumptions that apply to term 
discounts in general: that the package is billed monthly, at a flat rate, 
with no usage charges.  A prorated first month will be handled, as will 
a setup fee if the discount is allowed to apply to setup fees.

=cut

sub _items_discounts_avail {
  my $self = shift;
  my $list_pkgnums = 0; # if any packages are not eligible for all discounts

  my %plans = $self->discount_plans;

  $list_pkgnums = grep { $_->list_pkgnums } values %plans;

  map {
    my $months = $_;
    my $plan = $plans{$months};

    my $term_total = sprintf('%.2f', $plan->discounted_total);
    my $percent = sprintf('%.0f', 
                          100 * (1 - $term_total / $plan->base_total) );
    my $permonth = sprintf('%.2f', $term_total / $months);
    my $detail = $self->mt('discount on item'). ' '.
                 join(', ', map { "#$_" } $plan->pkgnums)
      if $list_pkgnums;

    # discounts for non-integer months don't work anyway
    $months = sprintf("%d", $months);

    +{
      description => $self->mt('Save [_1]% by paying for [_2] months',
                                $percent, $months),
      amount      => $self->mt('[_1] ([_2] per month)', 
                                $term_total, $money_char.$permonth),
      ext_description => ($detail || ''),
    }
  } #map
  sort { $b <=> $a } keys %plans;

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

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_re_X {
  my( $method, $job ) = ( shift, shift );
  warn "$me process_re_X $method for job $job\n" if $DEBUG;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  re_X(
    $method,
    $job,
    %$param,
  );

}

sub re_X {
  my($method, $job, %param ) = @_;
  if ( $DEBUG ) {
    warn "re_X $method for job $job with param:\n".
         join( '', map { "  $_ => ". $param{$_}. "\n" } keys %param );
  }

  #some false laziness w/search/cust_bill.html
  my $distinct = '';
  my $orderby = 'ORDER BY cust_bill._date';

  my $extra_sql = ' WHERE '. FS::cust_bill->search_sql_where(\%param);

  my $addl_from = 'LEFT JOIN cust_main USING ( custnum )';
     
  my @cust_bill = qsearch( {
    #'select'    => "cust_bill.*",
    'table'     => 'cust_bill',
    'addl_from' => $addl_from,
    'hashref'   => {},
    'extra_sql' => $extra_sql,
    'order_by'  => $orderby,
    'debug' => 1,
  } );

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

=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Valid parameters are

=over 4

=item _date

List reference of start date, end date, as UNIX timestamps.

=item invnum_min

=item invnum_max

=item agentnum

=item charged

List reference of charged limits (exclusive).

=item owed

List reference of charged limits (exclusive).

=item open

flag, return open invoices only

=item net

flag, return net invoices only

=item days

=item newest_percust

=back

Note: validates all passed-in data; i.e. safe to use with unchecked CGI params.

=cut

sub search_sql_where {
  my($class, $param) = @_;
  if ( $DEBUG ) {
    warn "$me search_sql_where called with params: \n".
         join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  }

  my @search = ();

  #agentnum
  if ( $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.agentnum = $1";
  }

  #refnum
  if ( $param->{'refnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.refnum = $1";
  }

  #custnum
  if ( $param->{'custnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.custnum = $1";
  }

  #customer classnum
  if ( $param->{'cust_classnum'} ) {
    my $classnums = $param->{'cust_classnum'};
    $classnums = [ $classnums ] if !ref($classnums);
    $classnums = [ grep /^\d+$/, @$classnums ];
    push @search, 'cust_main.classnum in ('.join(',',@$classnums).')'
      if @$classnums;
  }

  #_date
  if ( $param->{_date} ) {
    my($beginning, $ending) = @{$param->{_date}};

    push @search, "cust_bill._date >= $beginning",
                  "cust_bill._date <  $ending";
  }

  #invnum
  if ( $param->{'invnum_min'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.invnum >= $1";
  }
  if ( $param->{'invnum_max'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.invnum <= $1";
  }

  #charged
  if ( $param->{charged} ) {
    my @charged = ref($param->{charged})
                    ? @{ $param->{charged} }
                    : ($param->{charged});

    push @search, map { s/^charged/cust_bill.charged/; $_; }
                      @charged;
  }

  my $owed_sql = FS::cust_bill->owed_sql;

  #owed
  if ( $param->{owed} ) {
    my @owed = ref($param->{owed})
                 ? @{ $param->{owed} }
                 : ($param->{owed});
    push @search, map { s/^owed/$owed_sql/; $_; }
                      @owed;
  }

  #open/net flags
  push @search, "0 != $owed_sql"
    if $param->{'open'};
  push @search, '0 != '. FS::cust_bill->net_sql
    if $param->{'net'};

  #days
  push @search, "cust_bill._date < ". (time-86400*$param->{'days'})
    if $param->{'days'};

  #newest_percust
  if ( $param->{'newest_percust'} ) {

    #$distinct = 'DISTINCT ON ( cust_bill.custnum )';
    #$orderby = 'ORDER BY cust_bill.custnum ASC, cust_bill._date DESC';

    my @newest_where = map { my $x = $_;
                             $x =~ s/\bcust_bill\./newest_cust_bill./g;
                             $x;
                           }
                           grep ! /^cust_main./, @search;
    my $newest_where = scalar(@newest_where)
                         ? ' AND '. join(' AND ', @newest_where)
			 : '';


    push @search, "cust_bill._date = (
      SELECT(MAX(newest_cust_bill._date)) FROM cust_bill AS newest_cust_bill
        WHERE newest_cust_bill.custnum = cust_bill.custnum
          $newest_where
    )";

  }

  #promised_date - also has an option to accept nulls
  if ( $param->{promised_date} ) {
    my($beginning, $ending, $null) = @{$param->{promised_date}};

    push @search, "(( cust_bill.promised_date >= $beginning AND ".
                    "cust_bill.promised_date <  $ending )" .
                    ($null ? ' OR cust_bill.promised_date IS NULL ) ' : ')');
  }

  #agent virtualization
  my $curuser = $FS::CurrentUser::CurrentUser;
  if ( $curuser->username eq 'fs_queue'
       && $param->{'CurrentUser'} =~ /^(\w+)$/ ) {
    my $username = $1;
    my $newuser = qsearchs('access_user', {
      'username' => $username,
      'disabled' => '',
    } );
    if ( $newuser ) {
      $curuser = $newuser;
    } else {
      warn "$me WARNING: (fs_queue) can't find CurrentUser $username\n";
    }
  }
  push @search, $curuser->agentnums_sql;

  join(' AND ', @search );

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

