package FS::type_pkgs;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::type_pkgs - Object methods for type_pkgs records

=head1 SYNOPSIS

  use FS::type_pkgs;

  $record = create FS::type_pkgs \%hash;
  $record = create FS::type_pkgs { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::type_pkgs record links an agent type (see L<FS::agent_type>) to a
billing item definition (see L<FS::part_pkg>).  FS::type_pkgs inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item typenum - Agent type, see L<FS::agent_type>

=item pkgpart - Billing item definition, see L<FS::part_pkg>

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
  #foreach $field (fields('type_pkgs')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('type_pkgs',$hashref);

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
  return "(Old) Not a type_pkgs record!" unless $old->table eq "type_pkgs";

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
  return "Not a type_pkgs record!" unless $self->table eq "type_pkgs";
  my($recref) = $self->hashref;

  $recref->{typenum} =~ /^(\d+)$/ or return "Illegal typenum";
  $recref->{typenum} = $1;
  return "Unknown typenum"
    unless qsearchs('agent_type',{'typenum'=>$recref->{typenum}});

  $recref->{pkgpart} =~ /^(\d+)$/ or return "Illegal pkgpart";
  $recref->{pkgpart} = $1;
  return "Unknown pkgpart"
    unless qsearchs('part_pkg',{'pkgpart'=>$recref->{pkgpart}});

  ''; #no error
}

=back

=head1 HISTORY

Defines the relation between agent types and pkgparts
(Which pkgparts can the different [types of] agents sell?)

ivan@sisd.com 97-nov-13

change to ut_ FS::Record, fixed bugs
ivan@sisd.com 97-dec-10

=cut

1;

