package FS::svc_acct_pop;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields qsearchs);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::svc_acct_pop - Object methods for svc_acct_pop records

=head1 SYNOPSIS

  use FS::svc_acct_pop;

  $record = create FS::svc_acct_pop \%hash;
  $record = create FS::svc_acct_pop { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_acct object represents an point of presence.  FS::svc_acct_pop
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item popnum - primary key (assigned automatically for new accounts)

=item city

=item state

=item ac - area code

=item exch - exchange

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new point of presence (if only it were that easy!).  To add the 
point of presence to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('svc_acct_pop')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('svc_acct_pop',$hashref);
}

=item insert

Adds this point of presence to the databaes.  If there is an error, returns the
error, otherwise returns false.

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
  return "Can't (yet) delete POPs!";
  #$self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not an svc_acct_pop record!"
    unless $old->table eq "svc_acct_pop";
  return "Can't change popnum!"
    unless $old->getfield('popnum') eq $new->getfield('popnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid point of presence.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a svc_acct_pop record!" unless $self->table eq "svc_acct_pop";

  my($error)=
    $self->ut_numbern('popnum')
      or $self->ut_text('city')
      or $self->ut_text('state')
      or $self->ut_number('ac')
      or $self->ut_number('exch')
  ;
  return $error if $error;

  '';

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

It should be renamed to part_pop.

=head1 SEE ALSO

L<FS::Record>, L<svc_acct>, schema.html from the base documentation.

=head1 HISTORY

Class dealing with pops 

ivan@sisd.com 98-mar-8 

pod ivan@sisd.com 98-sep-23

=cut

1;

