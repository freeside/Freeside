package FS::cust_bill_pkg;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::cust_bill_pkg - Object methods for cust_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_bill_pkg;

  $record = create FS::cust_bill_pkg \%hash;
  $record = create FS::cust_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg object represents an invoice line item.
FS::cust_bill_pkg inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item invnum - invoice (see L<FS::cust_bill>)

=item pkgnum - package (see L<FS::cust_pkg>)

=item setup - setup fee

=item recur - recurring fee

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item create HASHREF

Creates a new line item.  To add the line item to the database, see
L<"insert">.  Line items are normally created by calling the bill method of a
customer object (see L<FS::cust_main>).

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_bill_pkg')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_bill_pkg',$hashref);

}

=item insert

Adds this line item to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.  I don't remove line items because there would then be
no record the items ever existed (which is bad, no?)

=cut

sub delete {
  return "Can't delete cust_bill_pkg records!";
  #my($self)=@_;
  #$self->del;
}

=item replace OLD_RECORD

Currently unimplemented.  This would be even more of an accounting nightmare
than deleteing the items.  Just don't do it.

=cut

sub replace {
  return "Can't modify cust_bill_pkg records!";
  #my($new,$old)=@_;
  #return "(Old) Not a cust_bill_pkg record!" 
  #  unless $old->table eq "cust_bill_pkg";
  #
  #$new->check or
  #$new->rep($old);
}

=item check

Checks all fields to make sure this is a valid line item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_bill_pkg record!" unless $self->table eq "cust_bill_pkg";

  my($error)=
    $self->ut_number('pkgnum')
      or $self->ut_number('invnum')
      or $self->ut_money('setup')
      or $self->ut_money('recur')
      or $self->ut_numbern('sdate')
      or $self->ut_numbern('edate')
  ;
  return $error if $error;

  if ( $self->pkgnum != 0 ) { #allow unchecked pkgnum 0 for tax! (add to part_pkg?)
    return "Unknown pkgnum ".$self->pkgnum
    unless qsearchs('cust_pkg',{'pkgnum'=> $self->pkgnum });
  }

  return "Unknown invnum"
    unless qsearchs('cust_bill',{'invnum'=> $self->invnum });

  ''; #no error
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, L<FS::cust_pkg>, L<FS::cust_main>, schema.html
from the base documentation.

=head1 HISTORY

ivan@sisd.com 98-mar-13

pod ivan@sisd.com 98-sep-21

=cut

1;

