package FS::cust_bill;

use strict;
use vars qw( @ISA $conf $add1 $add2 $add3 $add4 );
use Date::Format;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_bill_pkg;
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_pkg;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_bill'} = sub { 
  $conf = new FS::Conf;
  ( $add1, $add2, $add3, $add4 ) = ( $conf->config('address'), '', '', '', '' );
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

  @lines = $cust_bill->print_text;
  @lines = $cust_bill->print_text $time;

=head1 DESCRIPTION

An FS::cust_bill object represents an invoice.  FS::cust_bill inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item invnum - primary key (assigned automatically for new invoices)

=item custnum - customer (see L<FS::cust_main>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item charged - amount of this invoice

=item owed - amount still outstanding on this invoice, which is charged minus
all payments (see L<FS::cust_pay>).

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

When adding new invoices, owed must be charged (or null, in which case it is
automatically set to charged).

=cut

sub insert {
  my $self = shift;

  $self->owed( $self->charged ) if $self->owed eq '';
  return "owed != charged!"
    unless $self->owed == $self->charged;

  $self->SUPER::insert;
}

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

Only owed and printed may be changed.  Owed is normally updated by creating and
inserting a payment (see L<FS::cust_pay>).  Printed is normally updated by
calling the collect method of a customer object (see L<FS::cust_main>).

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );
  return "Can't change custnum!" unless $old->custnum == $new->custnum;
  #return "Can't change _date!" unless $old->_date eq $new->_date;
  return "Can't change _date!" unless $old->_date == $new->_date;
  return "Can't change charged!" unless $old->charged == $new->charged;
  return "(New) owed can't be > (new) charged!" if $new->owed > $new->charged;

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
    || $self->ut_money('owed')
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

Returns a list consisting of the total previous credited (see
L<FS::cust_credit>) for this customer, followed by the previous outstanding
credits (FS::cust_credit objects).

=cut

sub cust_credit {
  my $self = shift;
  my $total = 0;
  my @cust_credit = sort { $a->_date <=> $b->date }
    grep { $_->credited != 0 && $_->_date < $self->_date }
      qsearch('cust_credit', { 'custnum' => $self->custnum } )
  ;
  foreach (@cust_credit) { $total += $_->credited; }
  $total, @cust_credit;
}

=item cust_pay

Returns all payments (see L<FS::cust_pay>) for this invoice.

=cut

sub cust_pay {
  my $self = shift;
  sort { $a->_date <=> $b->date }
    qsearch( 'cust_pay', { 'invnum' => $self->invnum } )
  ;
}

=item print_text [TIME];

Returns an ASCII invoice, as a list of lines.

TIME an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub print_text {

  my( $self, $today ) = ( shift, shift );
  $today ||= time;
  my $invnum = $self->invnum;
  my $cust_main = qsearchs('cust_main', { 'custnum', $self->custnum } );
  $cust_main->payname( $cust_main->first. ' '. $cust_main->getfield('last') )
    unless $cust_main->payname;

  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
  my( $cr_total, @cr_cust_credit ) = $self->cust_credit; #credits
  my $balance_due = $self->owed + $pr_total - $cr_total;

  #overdue?
  my $overdue = ( 
    $balance_due > 0
    && $today > $self->_date 
    && $self->printed > 1
  );

  #printing bits here (yuck!)

  my @collect = ();

  my($description,$amount);
  my(@buf);

  #format address
  my($l,@address)=(0,'','','','','','','');
  $address[$l++] =
    $cust_main->payname.
      ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo
        ? " (P.O. #". $cust_main->payinfo. ")"
        : ''
      )
  ;
  $address[$l++]=$cust_main->company if $cust_main->company;
  $address[$l++]=$cust_main->address1;
  $address[$l++]=$cust_main->address2 if $cust_main->address2;
  $address[$l++]=$cust_main->city. ", ". $cust_main->state. "  ".
                 $cust_main->zip;
  $address[$l++]=$cust_main->country unless $cust_main->country eq 'US';

  #previous balance
  foreach ( @pr_cust_bill ) {
    push @buf, (
      "Previous Balance, Invoice #". $_->invnum. 
                 " (". time2str("%x",$_->_date). ")",
      '$'. sprintf("%10.2f",$_->owed)
    );
  }
  if (@pr_cust_bill) {
    push @buf,('','-----------');
    push @buf,('Total Previous Balance','$' . sprintf("%10.2f",$pr_total ) );
    push @buf,('','');
  }

  #new charges
  foreach ( $self->cust_bill_pkg ) {

    if ( $_->pkgnum ) {

      my($cust_pkg)=qsearchs('cust_pkg', { 'pkgnum', $_->pkgnum } );
      my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->pkgpart});
      my($pkg)=$part_pkg->pkg;

      if ( $_->setup != 0 ) {
        push @buf, ( "$pkg Setup",'$' . sprintf("%10.2f",$_->setup) );
        push @buf, map { "  ". $_->[0]. ": ". $_->[1], '' } $cust_pkg->labels;
      }

      if ( $_->recur != 0 ) {
        push @buf, (
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")",
          '$' . sprintf("%10.2f",$_->recur)
        );
        push @buf, map { "  ". $_->[0]. ": ". $_->[1], '' } $cust_pkg->labels;
      }

    } else { #pkgnum Tax
      push @buf,("Tax",'$' . sprintf("%10.2f",$_->setup) ) 
        if $_->setup != 0;
    }
  }

  push @buf,('','-----------');
  push @buf,('Total New Charges',
             '$' . sprintf("%10.2f",$self->charged) );
  push @buf,('','');

  push @buf,('','-----------');
  push @buf,('Total Charges',
             '$' . sprintf("%10.2f",$self->charged + $pr_total) );
  push @buf,('','');

  #credits
  foreach ( @cr_cust_credit ) {
    push @buf,(
      "Credit #". $_->crednum. " (" . time2str("%x",$_->_date) .")",
      '$' . sprintf("%10.2f",$_->credited)
    );
  }

  #get & print payments
  foreach ( $self->cust_pay ) {
    push @buf,(
      "Payment received ". time2str("%x",$_->_date ),
      '$' . sprintf("%10.2f",$_->paid )
    );
  }

  #balance due
  push @buf,('','-----------');
  push @buf,('Balance Due','$' . 
    sprintf("%10.2f",$self->owed + $pr_total - $cr_total ) );

  #now print

  my $tot_lines = 50; #should be configurable
   #header is 17 lines
  my $tot_pages = int( scalar(@buf) / ( 2 * ( $tot_lines - 17 ) ) );
  $tot_pages++ if scalar(@buf) % ( 2 * ( $tot_lines - 17 ) );

  my $page = 1;
  my $lines;
  while (@buf) {
    $lines = $tot_lines;
    my @header = &header(
      $page, $tot_pages, $self->_date, $self->invnum, @address
    );
    push @collect, @header;
    $lines -= scalar(@header);

    while ( $lines-- && @buf ) {
      $description=shift(@buf);
      $amount=shift(@buf);
      push @collect, myswrite($description, $amount);
    }
    $page++;
  }
  while ( $lines-- ) {
    push @collect, myswrite('', '');
  }

  return @collect;

  sub header { #17 lines
    my ( $page, $tot_pages, $date, $invnum, @address ) = @_ ;
    push @address, '', '', '', '';

    my @return = ();
    my $i = ' 'x32;
    push @return,
      '',
      $i. 'Invoice',
      $i. substr("Page $page of $tot_pages".' 'x10, 0, 20).
        time2str("%x", $date ). "  FS-". $invnum,
      '',
      '',
      $add1,
      $add2,
      $add3,
      $add4,
      '',
      splice @address, 0, 7;
    ;
    return map $_. "\n", @return;
  }

  sub myswrite {
    my $format = <<END;
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<
END
    $^A = '';
    formline( $format, @_ );
    return $^A;
  }

}

=back

=head1 VERSION

$Id: cust_bill.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

The delete method.

print_text formatting (and some logic :/) is in source, but needs to be
slurped in from a file.  Also number of lines ($=).

missing print_ps for a nice postscript copy (maybe HylaFAX-cover-page-style
or something similar so the look can be completely customized?)

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_pay>, L<FS::cust_bill_pkg>,
L<FS::cust_credit>, schema.html from the base documentation.

=cut

1;

