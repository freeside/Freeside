package FS::cust_main_county;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields hfields qsearch qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(hfields);

=head1 NAME

FS::cust_main_county - Object methods for cust_main_county objects

=head1 SYNOPSIS

  use FS::cust_main_county;

  $record = create FS::cust_main_county \%hash;
  $record = create FS::cust_main_county { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_main_county object represents a tax rate, defined by locale.
FS::cust_main_county inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxnum - primary key (assigned automatically for new tax rates)

=item state

=item county

=item country

=item tax - percentage

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new tax rate.  To add the tax rate to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_main_county')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_main_county',$hashref);
}

=item insert

Adds this tax rate to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Deletes this tax rate from the database.  If there is an error, returns the
error, otherwise returns false.

=cut

sub delete {
  my($self)=@_;

  $self->del;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_main_county record!"
    unless $old->table eq "cust_main_county";
  return "Can't change taxnum!"
    unless $old->getfield('taxnum') eq $new->getfield('taxnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid tax rate.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_main_county record!"
    unless $self->table eq "cust_main_county";
  my($recref) = $self->hashref;

  $self->ut_numbern('taxnum')
    or $self->ut_textn('state')
    or $self->ut_textn('county')
    or $self->ut_float('tax')
  ;

}

=back

=head1 VERSION

$Id: cust_main_county.pm,v 1.2 1998-11-18 09:01:43 ivan Exp $

=head1 BUGS

It doesn't properly override FS::Record yet.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=head1 HISTORY

ivan@voicenet.com 97-dec-16

Changed check for 'tax' to use the new ut_float subroutine
	bmccane@maxbaud.net	98-apr-3

pod ivan@sisd.com 98-sep-21

$Log: cust_main_county.pm,v $
Revision 1.2  1998-11-18 09:01:43  ivan
i18n! i18n!


=cut

1;

