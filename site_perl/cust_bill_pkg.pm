package FS::cust_bill_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::cust_pkg;
use FS::cust_bill;

@ISA = qw(FS::Record );

=head1 NAME

FS::cust_bill_pkg - Object methods for cust_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_bill_pkg;

  $record = new FS::cust_bill_pkg \%hash;
  $record = new FS::cust_bill_pkg { 'column' => 'value' };

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

=item new HASHREF

Creates a new line item.  To add the line item to the database, see
L<"insert">.  Line items are normally created by calling the bill method of a
customer object (see L<FS::cust_main>).

=cut

sub table { 'cust_bill_pkg'; }

=item insert

Adds this line item to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Currently unimplemented.  I don't remove line items because there would then be
no record the items ever existed (which is bad, no?)

=cut

sub delete {
  return "Can't delete cust_bill_pkg records!";
}

=item replace OLD_RECORD

Currently unimplemented.  This would be even more of an accounting nightmare
than deleteing the items.  Just don't do it.

=cut

sub replace {
  return "Can't modify cust_bill_pkg records!";
}

=item check

Checks all fields to make sure this is a valid line item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_number('pkgnum')
      || $self->ut_number('invnum')
      || $self->ut_money('setup')
      || $self->ut_money('recur')
      || $self->ut_numbern('sdate')
      || $self->ut_numbern('edate')
  ;
  return $error if $error;

  if ( $self->pkgnum != 0 ) { #allow unchecked pkgnum 0 for tax! (add to part_pkg?)
    return "Unknown pkgnum ". $self->pkgnum
      unless qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
  }

  return "Unknown invnum"
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  ''; #no error
}

=back

=head1 VERSION

$Id: cust_bill_pkg.pm,v 1.2 1998-12-29 11:59:37 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, L<FS::cust_pkg>, L<FS::cust_main>, schema.html
from the base documentation.

=head1 HISTORY

ivan@sisd.com 98-mar-13

pod ivan@sisd.com 98-sep-21

=cut

1;

