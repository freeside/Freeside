package FS::radius_usergroup;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::svc_acct;

@ISA = qw(FS::Record);

=head1 NAME

FS::radius_usergroup - Object methods for radius_usergroup records

=head1 SYNOPSIS

  use FS::radius_usergroup;

  $record = new FS::radius_usergroup \%hash;
  $record = new FS::radius_usergroup { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::radius_usergroup object links an account (see L<FS::svc_acct>) with a
RADIUS group.  FS::radius_usergroup inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item usergroupnum - primary key

=item svcnum - Account (see L<FS::svc_acct>).

=item groupname - group name

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'radius_usergroup'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

#inherited from FS::Record

=item delete

Delete this record from the database.

=cut

#inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

#inherited from FS::Record

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('usergroupnum')
    || $self->ut_number('svcnum')
    || $self->ut_foreign_key('svcnum','svc_acct','svcnum')
    || $self->ut_text('groupname')
    || $self->SUPER::check
  ;
}

=item svc_acct

Returns the account associated with this record (see L<FS::svc_acct>).

=cut

sub svc_acct {
  my $self = shift;
  qsearchs('svc_acct', { svcnum => $self->svcnum } );
}

=back

=head1 BUGS

Don't let 'em get you down.

=head1 SEE ALSO

L<svc_acct>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

