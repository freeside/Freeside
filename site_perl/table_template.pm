package FS::table_name;

use strict;
use vars qw (@ISA);
use Exporter;
#use FS::UID qw(getotaker);
use FS::Record qw(hfields qsearch qsearchs);

@ISA = qw(FS::Record);

=head1 NAME

FS::table_name - Object methods for table_name records

=head1 SYNOPSIS

  use FS::table_name;

  $record = create FS::table_name \%hash;
  $record = create FS::table_name { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::table_name object represents an example.  FS::table_name inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item field - description

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub create {
  my($proto,$hashref)=@_;

  $proto->new('table_name',$hashref);

}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  #local $SIG{HUP} = 'IGNORE';
  #local $SIG{INT} = 'IGNORE';
  #local $SIG{QUIT} = 'IGNORE';
  #local $SIG{TERM} = 'IGNORE';
  #local $SIG{TSTP} = 'IGNORE';

  $self->check or
  $self->add;
}

=item delete

Delete this record from the database.

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
  return "(Old) Not a table_name record!" unless $old->table eq "table_name";

  return "Can't change keyfield!"
     unless $old->getfield('keyfield') eq $new->getfield('keyfield');

  $new->check or
  $new->rep($old);
}


=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my($self)=@_;
  return "Not a table_name record!" unless $self->table eq "table_name";


  ''; #no error
}

=back

=head1 VERSION

$Id: table_template.pm,v 1.3 1998-11-15 04:33:00 ivan Exp $

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>

=head1 HISTORY

ivan@voicenet.com 97-jul-1

added hfields
ivan@sisd.com 97-nov-13

$Log: table_template.pm,v $
Revision 1.3  1998-11-15 04:33:00  ivan
updates for newest versoin

Revision 1.2  1998/11/15 03:48:49  ivan
update for current version


=cut

1;

