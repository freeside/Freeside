package FS::cust_bill;

use strict;
use vars qw( @ISA $conf $invoice_template $money_char );
use vars qw( $invoice_lines @buf ); #yuck
use Date::Format;
use Text::Template;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_bill_pkg;
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_pkg;
use FS::cust_credit_bill;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_bill'} = sub { 

  $conf = new FS::Conf;

  $money_char = $conf->config('money_char') || '$';  

  my @invoice_template = $conf->config('invoice_template')
    or die "cannot load config file invoice_template";
  $invoice_lines = 0;
  foreach ( grep /invoice_lines\(\d+\)/, @invoice_template ) { #kludgy
    /invoice_lines\((\d+)\)/;
    $invoice_lines += $1;
  }
  die "no invoice_lines() functions in template?" unless $invoice_lines;
  $invoice_template = new Text::Template (
    TYPE   => 'ARRAY',
    SOURCE => [ map "$_\n", @invoice_template ],
  ) or die "can't create new Text::Template object: $Text::Template::ERROR";
  $invoice_template->compile()
    or die "can't compile template: $Text::Template::ERROR";
};

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

=over 4

=item invnum - primary key (assigned automatically for new invoices)

=item custnum - customer (see L<FS::cust_main>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item charged - amount of this invoice

=item printed - how many times this invoice has been printed automatically
(see L<FS::cust_main/"collect">).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice.  To add the invoice to the database, see L<"insert">.
Invoices are normally created by calling the bill method of a customer object
(see L<FS::cust_main>).

=cut

sub table { 'cust_bill'; }

=item insert

Adds this invoice to the database ("Posts" the invoice).  If there is an error,
returns the error, otherwise returns false.

=item delete

Currently unimplemented.  I don't remove invoices because there would then be
no record you ever posted this invoice (which is bad, no?)

=cut

sub delete {
  return "Can't remove invoice!"
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Only printed may be changed.  printed is normally updated by calling the
collect method of a customer object (see L<FS::cust_main>).

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );
  return "Can't change custnum!" unless $old->custnum == $new->custnum;
  #return "Can't change _date!" unless $old->_date eq $new->_date;
  return "Can't change _date!" unless $old->_date == $new->_date;
  return "Can't change charged!" unless $old->charged == $new->charged;

  $new->SUPER::replace($old);
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
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
    || $self->ut_numbern('printed')
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->printed(0) if $self->printed eq '';

  ''; #no error
}

=item previous

Returns a list consisting of the total previous balance for this customer, 
followed by the previous outstanding invoices (as FS::cust_bill objects also).

=cut

sub previous {
  my $self = shift;
  my $total = 0;
  my @cust_bill = sort { $a->_date <=> $b->_date }
    grep { $_->owed != 0 && $_->_date < $self->_date }
      qsearch( 'cust_bill', { 'custnum' => $self->custnum } ) 
  ;
  foreach ( @cust_bill ) { $total += $_->owed; }
  $total, @cust_bill;
}

=item cust_bill_pkg

Returns the line items (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearch( 'cust_bill_pkg', { 'invnum' => $self->invnum } );
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

=item cust_bill_pay

Returns all payment applications (see L<FS::cust_bill_pay>) for this invoice.

=cut

sub cust_bill_pay {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_bill_pay', { 'invnum' => $self->invnum } );
}

=item cust_credited

Returns all applied credits (see L<FS::cust_credit_bill>) for this invoice.

=cut

sub cust_credited {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_bill', { 'invnum' => $self->invnum } )
  ;
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
}

=item print_text [TIME];

Returns an text invoice, as a list of lines.

TIME an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub print_text {

  my( $self, $today ) = ( shift, shift );
  $today ||= time;
#  my $invnum = $self->invnum;
  my $cust_main = qsearchs('cust_main', { 'custnum', $self->custnum } );
  $cust_main->payname( $cust_main->first. ' '. $cust_main->getfield('last') )
    unless $cust_main->payname;

  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
#  my( $cr_total, @cr_cust_credit ) = $self->cust_credit; #credits
  #my $balance_due = $self->owed + $pr_total - $cr_total;
  my $balance_due = $self->owed + $pr_total;

  #my @collect = ();
  #my($description,$amount);
  @buf = ();

  #previous balance
  foreach ( @pr_cust_bill ) {
    push @buf, [
      "Previous Balance, Invoice #". $_->invnum. 
                 " (". time2str("%x",$_->_date). ")",
      $money_char. sprintf("%10.2f",$_->owed)
    ];
  }
  if (@pr_cust_bill) {
    push @buf,['','-----------'];
    push @buf,[ 'Total Previous Balance',
                $money_char. sprintf("%10.2f",$pr_total ) ];
    push @buf,['',''];
  }

  #new charges
  foreach ( $self->cust_bill_pkg ) {

    if ( $_->pkgnum ) {

      my($cust_pkg)=qsearchs('cust_pkg', { 'pkgnum', $_->pkgnum } );
      my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->pkgpart});
      my($pkg)=$part_pkg->pkg;

      if ( $_->setup != 0 ) {
        push @buf, [ "$pkg Setup", $money_char. sprintf("%10.2f",$_->setup) ];
        push @buf,
          map { [ "  ". $_->[0]. ": ". $_->[1], '' ] } $cust_pkg->labels;
      }

      if ( $_->recur != 0 ) {
        push @buf, [
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")",
          $money_char. sprintf("%10.2f",$_->recur)
        ];
        push @buf,
          map { [ "  ". $_->[0]. ": ". $_->[1], '' ] } $cust_pkg->labels;
      }

    } else { #pkgnum Tax
      push @buf,["Tax", $money_char. sprintf("%10.2f",$_->setup) ] 
        if $_->setup != 0;
    }
  }

  push @buf,['','-----------'];
  push @buf,['Total New Charges',
             $money_char. sprintf("%10.2f",$self->charged) ];
  push @buf,['',''];

  push @buf,['','-----------'];
  push @buf,['Total Charges',
             $money_char. sprintf("%10.2f",$self->charged + $pr_total) ];
  push @buf,['',''];

  #credits
  foreach ( $self->cust_credited ) {

    #something more elaborate if $_->amount ne $_->cust_credit->credited ?

    my $reason = substr($_->cust_credit->reason,0,32);
    $reason .= '...' if length($reason) < length($_->cust_credit->reason);
    $reason = " ($reason) " if $reason;
    push @buf,[
      "Credit #". $_->crednum. " (". time2str("%x",$_->cust_credit->_date) .")".
        $reason,
      $money_char. sprintf("%10.2f",$_->amount)
    ];
  }
  #foreach ( @cr_cust_credit ) {
  #  push @buf,[
  #    "Credit #". $_->crednum. " (" . time2str("%x",$_->_date) .")",
  #    $money_char. sprintf("%10.2f",$_->credited)
  #  ];
  #}

  #get & print payments
  foreach ( $self->cust_bill_pay ) {

    #something more elaborate if $_->amount ne ->cust_pay->paid ?

    push @buf,[
      "Payment received ". time2str("%x",$_->cust_pay->_date ),
      $money_char. sprintf("%10.2f",$_->amount )
    ];
  }

  #balance due
  push @buf,['','-----------'];
  push @buf,['Balance Due', $money_char. 
    sprintf("%10.2f", $balance_due ) ];

  #setup template variables
  
  package FS::cust_bill::_template; #!
  use vars qw( $invnum $date $page $total_pages @address $overdue @buf );

  $invnum = $self->invnum;
  $date = $self->_date;
  $page = 1;

  $total_pages =
    int( scalar(@FS::cust_bill::buf) / $FS::cust_bill::invoice_lines );
  $total_pages++
    if scalar(@FS::cust_bill::buf) % $FS::cust_bill::invoice_lines;


  #format address (variable for the template)
  my $l = 0;
  @address = ( '', '', '', '', '', '' );
  package FS::cust_bill; #!
  $FS::cust_bill::_template::address[$l++] =
    $cust_main->payname.
      ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo
        ? " (P.O. #". $cust_main->payinfo. ")"
        : ''
      )
  ;
  $FS::cust_bill::_template::address[$l++] = $cust_main->company
    if $cust_main->company;
  $FS::cust_bill::_template::address[$l++] = $cust_main->address1;
  $FS::cust_bill::_template::address[$l++] = $cust_main->address2
    if $cust_main->address2;
  $FS::cust_bill::_template::address[$l++] =
    $cust_main->city. ", ". $cust_main->state. "  ".  $cust_main->zip;
  $FS::cust_bill::_template::address[$l++] = $cust_main->country
    unless $cust_main->country eq 'US';

  #overdue? (variable for the template)
  $FS::cust_bill::_template::overdue = ( 
    $balance_due > 0
    && $today > $self->_date 
#    && $self->printed > 1
    && $self->printed > 0
  );

  #and subroutine for the template

  sub FS::cust_bill::_template::invoice_lines {
    my $lines = shift;
    map { 
      scalar(@buf) ? shift @buf : [ '', '' ];
    }
    ( 1 .. $lines );
  }
    
  $FS::cust_bill::_template::page = 1;
  my $lines;
  my @collect;
  while (@buf) {
    push @collect, split("\n",
      $invoice_template->fill_in( PACKAGE => 'FS::cust_bill::_template' )
    );
    $FS::cust_bill::_template::page++;
  }

  map "$_\n", @collect;

}

=back

=head1 VERSION

$Id: cust_bill.pm,v 1.13 2001-12-17 23:59:56 ivan Exp $

=head1 BUGS

The delete method.

print_text formatting (and some logic :/) is in source, but needs to be
slurped in from a file.  Also number of lines ($=).

missing print_ps for a nice postscript copy (maybe HylaFAX-cover-page-style
or something similar so the look can be completely customized?)

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill_pay>, L<FS:;cust_pay>,
L<FS::cust_bill_pkg>, L<FS::cust_bill_credit>, schema.html from the base
documentation.

=cut

1;

