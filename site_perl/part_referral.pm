package FS::part_referral;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::part_referral - Object methods for part_referral objects

=head1 SYNOPSIS

  use FS::part_referral;

  $record = create FS::part_referral \%hash
  $record = create FS::part_referral { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_referral represents a referral - where a customer heard of your
services.  This can be used to track the effectiveness of a particular piece of
advertising, for example.  FS::part_referral inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item refnum - primary key (assigned automatically for new referrals)

=item referral - Text name of this referral

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new referral.  To add the referral to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('part_referral')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('part_referral',$hashref);
}

=item insert

Adds this referral to the database.  If there is an error, returns the error,
otherwise returns false.

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
  my($self)=@_;
  return "Can't (yet?) delete part_referral records";
  #$self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not an part_referral record!" 
    unless $old->table eq "part_referral";
  return "Can't change refnum!"
    unless $old->getfield('refnum') eq $new->getfield('refnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid referral.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a part_referral record!" unless $self->table eq "part_referral";

  my($error)=
    $self->ut_numbern('refnum')
      or $self->ut_text('referral')
  ;
  return $error if $error;

  '';

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

The delete method is unimplemented.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, schema.html from the base documentation.

=head1 HISTORY

Class dealing with referrals

ivan@sisd.com 98-feb-23

pod ivan@sisd.com 98-sep-21

=cut

1;

