package FS::cust_credit;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::UID qw(getotaker);
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::cust_credit - Object methods for cust_credit records

=head1 SYNOPSIS

  use FS::cust_credit;

  $record = create FS::cust_credit \%hash;
  $record = create FS::cust_credit { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit object represents a credit.  FS::cust_credit inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item crednum - primary key (assigned automatically for new credits)

=item custnum - customer (see L<FS::cust_main>)

=item amount - amount of the credit

=item credited - how much of this credit that is still outstanding, which is
amount minus all refunds (see L<FS::cust_refund>).

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=item reason - text

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new credit.  To add the credit to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_credit')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_credit',$hashref);
}

=item insert

Adds this credit to the database ("Posts" the credit).  If there is an error,
returns the error, otherwise returns false.

When adding new invoices, credited must be amount (or null, in which case it is
automatically set to amount).

=cut

sub insert {
  my($self)=@_;

  $self->setfield('credited',$self->amount) if $self->credited eq '';
  return "credited != amount!"
    unless $self->credited == $self->amount;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't remove credit!"
  #my($self)=@_;
  #$self->del;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Only credited may be changed.  Credited is normally updated by creating and
inserting a refund (see L<FS::cust_refund>).

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_credit record!" unless $old->table eq "cust_credit";
  return "Can't change crednum!"
    unless $old->getfield('crednum') eq $new->getfield('crednum');
  return "Can't change custnum!"
    unless $old->getfield('custnum') eq $new->getfield('custnum');
  return "Can't change date!"
    unless $old->getfield('_date') eq $new->getfield('_date');
  return "Can't change amount!"
    unless $old->getfield('amount') eq $new->getfield('amount');
  return "(New) credited can't be > (new) amount!"
    if $new->getfield('credited') > $new->getfield('amount');

  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid credit.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_credit record!" unless $self->table eq "cust_credit";
  my($recref) = $self->hashref;

  $recref->{crednum} =~ /^(\d*)$/ or return "Illegal crednum";
  $recref->{crednum} = $1;

  $recref->{custnum} =~ /^(\d+)$/ or return "Illegal custnum";
  $recref->{custnum} = $1;
  return "Unknown customer"
    unless qsearchs('cust_main',{'custnum'=>$recref->{custnum}});

  $recref->{_date} =~ /^(\d*)$/ or return "Illegal date";
  $recref->{_date} = $recref->{_date} ? $1 : time;

  $recref->{amount} =~ /^(\d+(\.\d\d)?)$/ or return "Illegal amount";
  $recref->{amount} = $1;

  $recref->{credited} =~ /^(\-?\d+(\.\d\d)?)$/ or return "Illegal credited";
  $recref->{credited} = $1;

  #$recref->{otaker} =~ /^(\w+)$/ or return "Illegal otaker";
  #$recref->{otaker} = $1;
  $self->otaker(getotaker);

  $self->ut_textn('reason');

}

=back

=head1 BUGS

The delete method.

It doesn't properly override FS::Record yet.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, schema.html from the base
documentation.

=head1 HISTORY

ivan@sisd.com 98-mar-17

pod, otaker from FS::UID ivan@sisd.com 98-sep-21

=cut

1;

