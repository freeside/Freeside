package FS::cust_refund;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use Business::CreditCard;
use FS::Record qw(fields qsearchs);
use FS::UID qw(getotaker);
use FS::cust_credit;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::cust_refund - Object method for cust_refund objects

=head1 SYNOPSIS

  use FS::cust_refund;

  $record = create FS::cust_refund \%hash;
  $record = create FS::cust_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_refund represents a refund.  FS::cust_refund inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item refundnum - primary key (assigned automatically for new refunds)

=item crednum - Credit (see L<FS::cust_credit>)

=item refund - Amount of the refund

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new refund.  To add the refund to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_refund')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_refund',$hashref);

}

=item insert

Adds this refund to the database, and updates the credit (see
L<FS::cust_credit>).

=cut

sub insert {
  my($self)=@_;

  my($error);

  $error=$self->check;
  return $error if $error;

  my($old_cust_credit) = qsearchs('cust_credit', {
                                'crednum' => $self->getfield('crednum')
                               } );
  return "Unknown crednum" unless $old_cust_credit;
  my(%hash)=$old_cust_credit->hash;
  $hash{credited} = sprintf("%.2f",$hash{credited} - $self->getfield('refund') );
  my($new_cust_credit) = create FS::cust_credit ( \%hash );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$new_cust_credit -> replace($old_cust_credit);
  return "Error modifying cust_credit: $error" if $error;

  $self->add;
}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_refund records!";
#template code below
#  my($self)=@_;
#
#  $self->del;
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_refund records!";
#template code below
#  my($new,$old)=@_;
#  return "(Old) Not a cust_refund record!" unless $old->table eq "cust_refund";
#
#  $new->check or
#  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid refund.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_refund record!" unless $self->table eq "cust_refund";

  my $error =
    $self->ut_number('refundnum')
    || $self->ut_number('crednum')
    || $self->ut_money('amount')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  my($recref) = $self->hashref;

  $recref->{_date} ||= time;

  $recref->{payby} =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $recref->{payby} = $1;

  if ( $recref->{payby} eq 'CARD' ) {

    $recref->{payinfo} =~ s/\D//g;
    if ( $recref->{payinfo} ) {
      $recref->{payinfo} =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $recref->{payinfo} = $1;
      #validate($recref->{payinfo})
      #  or return "Illegal (checksum) credit card number (payinfo)";
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

  $self->otaker(getotaker);

  ''; #no error
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit>, schema.html from the base documentation.

=head1 HISTORY

ivan@sisd.com 98-mar-18

->create had wrong tablename ivan@sisd.com 98-jun-16
(finish me!)

pod and finish up ivan@sisd.com 98-sep-21

=cut

1;

