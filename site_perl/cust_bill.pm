package FS::cust_bill;

use strict;
use vars qw(@ISA $conf $add1 $add2 $add3 $add4);
use Exporter;
use Date::Format;
use FS::Record qw(fields qsearch qsearchs);

@ISA = qw(FS::Record Exporter);

$conf = new FS::Conf;

($add1,$add2,$add3,$add4) = $conf->config('address');

=head1 NAME

FS::cust_bill - Object methods for cust_bill records

=head1 SYNOPSIS

  use FS::cust_bill;

  $record = create FS::cust_bill \%hash;
  $record = create FS::cust_bill { 'column' => 'value' };

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

=item create HASHREF

Creates a new invoice.  To add the invoice to the database, see L<"insert">.
Invoices are normally created by calling the bill method of a customer object
(see L<FS::cust_main>).

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_bill')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_bill',$hashref);
}

=item insert

Adds this invoice to the database ("Posts" the invoice).  If there is an error,
returns the error, otherwise returns false.

When adding new invoices, owed must be charged (or null, in which case it is
automatically set to charged).

=cut

sub insert {
  my($self)=@_;

  $self->setfield('owed',$self->charged) if $self->owed eq '';
  return "owed != charged!"
    unless $self->owed == $self->charged;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.  I don't remove invoices because there would then be
no record you ever posted this invoice (which is bad, no?)

=cut

sub delete {
  return "Can't remove invoice!"
  #my($self)=@_;
  #$self->del;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Only owed and printed may be changed.  Owed is normally updated by creating and
inserting a payment (see L<FS::cust_pay>).  Printed is normally updated by
calling the collect method of a customer object (see L<FS::cust_main>).

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_bill record!" unless $old->table eq "cust_bill";
  return "Can't change invnum!"
    unless $old->getfield('invnum') eq $new->getfield('invnum');
  return "Can't change custnum!"
    unless $old->getfield('custnum') eq $new->getfield('custnum');
  return "Can't change _date!"
    unless $old->getfield('_date') eq $new->getfield('_date');
  return "Can't change charged!"
    unless $old->getfield('charged') eq $new->getfield('charged');
  return "(New) owed can't be > (new) charged!"
    if $new->getfield('owed') > $new->getfield('charged');

  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid invoice.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_bill record!" unless $self->table eq "cust_bill";
  my($recref) = $self->hashref;

  $recref->{invnum} =~ /^(\d*)$/ or return "Illegal invnum";
  $recref->{invnum} = $1;

  $recref->{custnum} =~ /^(\d+)$/ or return "Illegal custnum";
  $recref->{custnum} = $1;
  return "Unknown customer"
    unless qsearchs('cust_main',{'custnum'=>$recref->{custnum}});

  $recref->{_date} =~ /^(\d*)$/ or return "Illegal date";
  $recref->{_date} = $recref->{_date} ? $1 : time;

  #$recref->{charged} =~ /^(\d+(\.\d\d)?)$/ or return "Illegal charged";
  $recref->{charged} =~ /^(\-?\d+(\.\d\d)?)$/ or return "Illegal charged";
  $recref->{charged} = $1;

  $recref->{owed} =~ /^(\-?\d+(\.\d\d)?)$/ or return "Illegal owed";
  $recref->{owed} = $1;

  $recref->{printed} =~ /^(\d*)$/ or return "Illegal printed";
  $recref->{printed} = $1 || '0';

  ''; #no error
}

=item previous

Returns a list consisting of the total previous balance for this customer, 
followed by the previous outstanding invoices (as FS::cust_bill objects also).

=cut

sub previous {
  my($self)=@_;
  my($total)=0;
  my(@cust_bill) = sort { $a->_date <=> $b->_date }
    grep { $_->owed != 0 && $_->_date < $self->_date }
      qsearch('cust_bill',{ 'custnum' => $self->custnum } ) 
  ;
  foreach (@cust_bill) { $total += $_->owed; }
  $total, @cust_bill;
}

=item cust_bill_pkg

Returns the line items (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub cust_bill_pkg {
  my($self)=@_;
  qsearch( 'cust_bill_pkg', { 'invnum' => $self->invnum } );
}

=item cust_credit

Returns a list consisting of the total previous credited (see
L<FS::cust_credit>) for this customer, followed by the previous outstanding
credits (FS::cust_credit objects).

=cut

sub cust_credit {
  my($self)=@_;
  my($total)=0;
  my(@cust_credit) = sort { $a->_date <=> $b->date }
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
  my($self)=@_;
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

  my($self,$today)=@_;
  $today ||= time;
  my($invnum)=$self->invnum;
  my($cust_main) = qsearchs('cust_main', 
                            { 'custnum', $self->custnum } );
  $cust_main->setfield('payname',
    $cust_main->first. ' '. $cust_main->getfield('last')
  ) unless $cust_main->payname;

  my($pr_total,@pr_cust_bill) = $self->previous; #previous balance
  my($cr_total,@cr_cust_credit) = $self->cust_credit; #credits
  my($balance_due) = $self->owed + $pr_total - $cr_total;

  #overdue?
  my($overdue) = ( 
    $balance_due > 0
    && $today > $self->_date 
    && $self->printed > 1
  );

  #printing bits here

  local($SIG{CHLD}) = sub { wait() };
  $|=1;
  my($pid)=open(CHILD,"-|");
  die "Can't fork: $!" unless defined($pid); 

  if ($pid) { #parent
    my(@collect)=<CHILD>;
    close CHILD;
    return @collect;
  } else { #child

    my($description,$amount);
    my(@buf);

    #define format stuff
    $%=0;
    $= = 35;
    local($^L) = <<END;







END

    #format address
    my($l,@address)=(0,'','','','','');
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

        push @buf, ( "$pkg Setup",'$' . sprintf("%10.2f",$_->setup) )
          if $_->setup != 0;
        push @buf, (
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")",
          '$' . sprintf("%10.2f",$_->recur)
        ) if $_->recur != 0;

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

    my($tot_pages)=int(scalar(@buf)/30); #15 lines, 2 values per line
    $tot_pages++ if scalar(@buf) % 30;

    while (@buf) {
      $description=shift(@buf);
      $amount=shift(@buf);
      write;
    }
      ($description,$amount)=('','');
      write while ( $- );
      print $^L;

      exit; #kid

    format STDOUT_TOP =

                                      @|||||||||||||||||||
                                     "Invoice"
                                      @||||||||||||||||||| @<<<<<<< @<<<<<<<<<<<
{
              ( $tot_pages != 1 ) ? "Page $% of $tot_pages" : '',
  time2str("%x",( $self->_date )), "FS-$invnum"
}


@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$add1
@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$add2
@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$add3
@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$add4

  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
{ $cust_main->payname,
  ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo )
  ? "P.O. #". $cust_main->payinfo : ''
}
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$address[0],''
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$address[1],$overdue ? "* This invoice is now PAST DUE! *" : ''
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$address[2],$overdue ? " Please forward payment promptly " : ''
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$address[3],$overdue ? "to avoid interruption of service." : ''
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<             @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$address[4],''



.

    format STDOUT =
  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<
  $description,$amount
.

  } #endchild

}

=back

=head1 BUGS

The delete method.

It doesn't properly override FS::Record yet.

print_text formatting (and some logic :/) is in source as a format declaration,
which needs to be slurped in from a file.  the fork is rather kludgy as well.
It could be cleaned with swrite from man perlform, and the picture could be
put in a /var/spool/freeside/conf file.  Also number of lines ($=).

missing print_ps for a nice postscript copy (maybe HylaFAX-cover-page-style
or something similar so the look can be completely customized?)

There is an off-by-one error in print_text which causes a visual error: "Page 1
of 2" printed on some single-page invoices?

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_pay>, L<FS::cust_bill_pkg>,
L<FS::cust_credit>, schema.html from the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-1

small fix for new API ivan@sisd.com 98-mar-14

charges can be negative ivan@sisd.com 98-jul-13

pod, ingegrate with FS::Invoice ivan@sisd.com 98-sep-20

$Log: cust_bill.pm,v $
Revision 1.2  1998-11-07 10:24:24  ivan
don't use depriciated FS::Bill and FS::Invoice, other miscellania


=cut

1;

