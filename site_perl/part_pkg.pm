package FS::part_pkg;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields hfields);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(hfields fields);

=head1 NAME

FS::part_pkg - Object methods for part_pkg objects

=head1 SYNOPSIS

  use FS::part_pkg;

  $record = create FS::part_pkg \%hash
  $record = create FS::part_pkg { 'column' => 'value' };

  $custom_record = $template_record->clone;

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg represents a billing item definition.  FS::part_pkg inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item pkgpart - primary key (assigned automatically for new billing item definitions)

=item pkg - Text name of this billing item definition (customer-viewable)

=item comment - Text name of this billing item definition (non-customer-viewable)

=item setup - Setup fee

=item freq - Frequency of recurring fee

=item recur - Recurring fee

=back

setup and recur are evaluated as Safe perl expressions.  You can use numbers
just as you would normally.  More advanced semantics are not yet defined.

=head1 METHODS

=over 4 

=item create HASHREF

Creates a new billing item definition.  To add the billing item definition to
the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('part_pkg')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('part_pkg',$hashref);
}

=item clone

Creates a new billing item definition by duplicating an existing definition.
A new pkgpart is assigned and "(CUSTOM) " is prepended to the comment field.
To add the billing item definition to the database, see L<"insert">.

=cut

sub clone {
  my $self = shift;
  my %hash = $self->hash;
  $hash{'pkgpart'} = '';
  $hash{'comment'} = "(CUSTOM) ". $hash{'comment'}
    unless $hash{'comment'} =~ /^\(CUSTOM\) /;
  create FS::part_pkg ( \%hash ); # ?
}

=item insert

Adds this billing item definition to the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't (yet?) delete package definitions.";
# maybe check & make sure the pkgpart isn't in cust_pkg or type_pkgs?
#  my($self)=@_;
#
#  $self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a part_pkg record!" unless $old->table eq "part_pkg";
  return "Can't change pkgpart!"
    unless $old->getfield('pkgpart') eq $new->getfield('pkgpart');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid billing item definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a part_pkg record!" unless $self->table eq "part_pkg";

  $self->ut_numbern('pkgpart')
    or $self->ut_text('pkg')
    or $self->ut_text('comment')
    or $self->ut_anything('setup')
    or $self->ut_number('freq')
    or $self->ut_anything('recur')
  ;

}

=back

=head1 VERSION

$Id: part_pkg.pm,v 1.3 1998-11-15 13:00:15 ivan Exp $

=head1 BUGS

It doesn't properly override FS::Record yet.

The delete method is unimplemented.

setup and recur semantics are not yet defined (and are implemented in
FS::cust_bill.  hmm.).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=head1 HISTORY

ivan@sisd.com 97-dec-5

pod ivan@sisd.com 98-sep-21

$Log: part_pkg.pm,v $
Revision 1.3  1998-11-15 13:00:15  ivan
bugfix in clone method, clone method doc clarification


=cut

1;

