package FS::pkg_svc;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields hfields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(hfields);

=head1 NAME

FS::pkg_svc - Object methods for pkg_svc records

=head1 SYNOPSIS

  use FS::pkg_svc;

  $record = create FS::pkg_svc \%hash;
  $record = create FS::pkg_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_svc record links a billing item definition (see L<FS::part_pkg>) to
a service definition (see L<FS::part_svc>).  FS::pkg_svc inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item pkgpart - Billing item definition (see L<FS::part_pkg>)

=item svcpart - Service definition (see L<FS::part_svc>)

=item quantity - Quantity of this service definition that this billing item
definition includes

=back

=head1 METHODS

=over 4

=item create HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('pkg_svc')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('pkg_svc',$hashref);

}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=cut

sub delete {
  my($self)=@_;

  $self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a pkg_svc record!" unless $old->table eq "pkg_svc";
  return "Can't change pkgpart!"
    if $old->getfield('pkgpart') ne $new->getfield('pkgpart');
  return "Can't change svcpart!"
    if $old->getfield('svcpart') ne $new->getfield('svcpart');

  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a pkg_svc record!" unless $self->table eq "pkg_svc";
  my($recref) = $self->hashref;

  my($error);
  return $error if $error =
    $self->ut_number('pkgpart')
    || $self->ut_number('svcpart')
    || $self->ut_number('quantity')
  ;

  return "Unknown pkgpart!"
    unless qsearchs('part_pkg',{'pkgpart'=> $self->getfield('pkgpart')});

  return "Unknown svcpart!"
    unless qsearchs('part_svc',{'svcpart'=> $self->getfield('svcpart')});

  ''; #no error
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

=head1 SEE ALSO

L<FS::Record>, L<FS::part_pkg>, L<FS::part_svc>, schema.html from the base
documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-1
 
added hfields
ivan@sisd.com 97-nov-13

pod ivan@sisd.com 98-sep-22

=cut

1;

