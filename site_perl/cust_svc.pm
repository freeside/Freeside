package FS::cust_svc;

use strict;
use vars qw(@ISA);
use Exporter;
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);

=head1 NAME

FS::cust_svc - Object method for cust_svc objects

=head1 SYNOPSIS

  use FS::cust_svc;

  $record = create FS::cust_svc \%hash
  $record = create FS::cust_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_svc represents a service.  FS::cust_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatically for new services)

=item pkgnum - Package (see L<FS::cust_pkg>)

=item svcpart - Service definition (see L<FS::part_svc>)

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new service.  To add the refund to the database, see L<"insert">.
Services are normally created by creating FS::svc_ objects (see
L<FS::svc_acct>, L<FS::svc_domain>, and L<FS::svc_acct_sm>, among others).

=cut

sub create {
  my($proto,$hashref)=@_; 

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_svc')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_svc',$hashref);
}

=item insert

Adds this service to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Deletes this service from the database.  If there is an error, returns the
error, otherwise returns false.

Called by the cancel method of the package (see L<FS::cust_pkg>).

=cut

sub delete {
  my($self)=@_;
  # anything else here?
  $self->del;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_svc record!" unless $old->table eq "cust_svc";
  return "Can't change svcnum!"
    unless $old->getfield('svcnum') eq $new->getfield('svcnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otehrwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_svc record!" unless $self->table eq "cust_svc";
  my($recref) = $self->hashref;

  $recref->{svcnum} =~ /^(\d*)$/ or return "Illegal svcnum";
  $recref->{svcnum}=$1;

  $recref->{pkgnum} =~ /^(\d*)$/ or return "Illegal pkgnum";
  $recref->{pkgnum}=$1;
  return "Unknown pkgnum" unless
    ! $recref->{pkgnum} ||
    qsearchs('cust_pkg',{'pkgnum'=>$recref->{pkgnum}});

  $recref->{svcpart} =~ /^(\d+)$/ or return "Illegal svcpart";
  $recref->{svcpart}=$1;
  return "Unknown svcpart" unless
    qsearchs('part_svc',{'svcpart'=>$recref->{svcpart}});

  ''; #no error
}

=back

=head1 BUGS

Behaviour of changing the svcpart of cust_svc records is undefined and should
possibly be prohibited, and pkg_svc records are not checked.

pkg_svc records are not checket in general (here).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::part_svc>, L<FS::pkg_svc>, 
schema.html from the base documentation

=head1 HISTORY

ivan@voicenet.com 97-jul-10,14

no TableUtil, no FS::Lock ivan@sisd.com 98-mar-7

pod ivan@sisd.com 98-sep-21

=cut

1;

