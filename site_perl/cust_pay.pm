package FS::cust_pay;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use Business::CreditCard;
use FS::Record qw(fields qsearchs);
use FS::cust_bill;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::cust_pay - Object methods for cust_pay objects

=head1 SYNOPSIS

  use FS::cust_pay;

  $record = create FS::cust_pay \%hash;
  $record = create FS::cust_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay object represents a payment.  FS::cust_pay inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item paynum - primary key (assigned automatically for new payments)

=item invnum - Invoice (see L<FS::cust_bill>)

=item paid - Amount of this payment

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item paybatch - text field for tracking card processing

=back

=head1 METHODS

=over 4 

=item create HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_pay')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_pay',$hashref);

}

=item insert

Adds this payment to the databse, and updates the invoice (see
L<FS::cust_bill>).

=cut

sub insert {
  my($self)=@_;

  my($error);

  $error=$self->check;
  return $error if $error;

  my($old_cust_bill) = qsearchs('cust_bill', {
                                'invnum' => $self->getfield('invnum')
                               } );
  return "Unknown invnum" unless $old_cust_bill;
  my(%hash)=$old_cust_bill->hash;
  $hash{owed} = sprintf("%.2f",$hash{owed} - $self->getfield('paid') );
  my($new_cust_bill) = create FS::cust_bill ( \%hash );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$new_cust_bill -> replace($old_cust_bill);
  return "Error modifying cust_bill: $error" if $error;

  $self->add;
}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_pay records!";
#template code below
#  my($self)=@_;
#
#  $self->del;
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_pay records!";
#template code below
#  my($new,$old)=@_;
#  return "(Old) Not a cust_pay record!" unless $old->table eq "cust_pay";
#
#  $new->check or
#  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid payment.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_pay record!" unless $self->table eq "cust_pay";
  my($recref) = $self->hashref;

  $recref->{paynum} =~ /^(\d*)$/ or return "Illegal paynum";
  $recref->{paynum} = $1;

  $recref->{invnum} =~ /^(\d+)$/ or return "Illegal invnum";
  $recref->{invnum} = $1;

  $recref->{paid} =~ /^(\d+(\.\d\d)?)$/ or return "Illegal paid";
  $recref->{paid} = $1;

  $recref->{_date} =~ /^(\d*)$/ or return "Illegal date";
  $recref->{_date} = $recref->{_date} ? $1 : time;

  $recref->{payby} =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $recref->{payby} = $1;

  if ( $recref->{payby} eq 'CARD' ) {

    $recref->{payinfo} =~ s/\D//g;
    if ( $recref->{payinfo} ) {
      $recref->{payinfo} =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $recref->{payinfo} = $1;
      #validate($recref->{payinfo})
      #  or return "Illegal credit card number";
      my($type)=cardtype($recref->{payinfo});
      return "Unknown credit card type"
        unless ( $type =~ /^VISA/ ||
                 $type =~ /^MasterCard/ ||
                 $type =~ /^American Express/ ||
                 $type =~ /^Discover/ );
    } else {
      $recref->{payinfo}='N/A';
    }

  } elsif ( $recref->{payby} eq 'BILL' ) {

    $recref->{payinfo} =~ /^([\w \-]*)$/
      or return "Illegal P.O. number (payinfo)";
    $recref->{payinfo} = $1;

  } elsif ( $recref->{payby} eq 'COMP' ) {

    $recref->{payinfo} =~ /^([\w]{2,8})$/
      or return "Illegal comp account issuer (payinfo)";
    $recref->{payinfo} = $1;

  }

  $recref->{paybatch} =~ /^([\w\-\:]*)$/
    or return "Illegal paybatch";
  $recref->{paybatch} = $1;

  ''; #no error

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, schema.html from the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-1 - 25 - 29

new api ivan@sisd.com 98-mar-13

pod ivan@sisd.com 98-sep-21

=cut

1;

