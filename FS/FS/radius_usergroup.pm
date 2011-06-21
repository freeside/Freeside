package FS::radius_usergroup;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::svc_acct;
use FS::radius_group;

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
RADIUS group (see L<FS::radius_group>).  FS::radius_usergroup inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item usergroupnum - primary key

=item svcnum - Account (see L<FS::svc_acct>).

=item groupnum - RADIUS group (see L<FS::radius_group>).

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

  die "radius_usergroup.groupname is deprecated" if $self->groupname;

  $self->ut_numbern('usergroupnum')
    || $self->ut_foreign_key('svcnum','svc_acct','svcnum')
    || $self->ut_foreign_key('groupnum','radius_group','groupnum')
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

=item radius_group

Returns the RADIUS group associated with this record (see L<FS::radius_group>).

=cut

sub radius_group {
  my $self = shift;
  qsearchs('radius_group', { 'groupnum'  => $self->groupnum } );
}

sub _upgrade_data {  #class method
  my ($class, %opts) = @_;

  my %group_cache = map { $_->groupname => $_->groupnum } 
                                                qsearch('radius_group', {});

  my @radius_usergroup = qsearch('radius_usergroup', {} );
  my $error = '';
  foreach my $rug ( @radius_usergroup ) {
        my $groupname = $rug->groupname;
        next unless $groupname;
        unless(defined($group_cache{$groupname})) {
            my $g = new FS::radius_group {
                            'groupname' => $groupname,
                            'description' => $groupname,
                            };
            $error = $g->insert;
            die $error if $error;
            $group_cache{$groupname} = $g->groupnum;
        }
        $rug->groupnum($group_cache{$groupname});
        $rug->groupname('');
        $error = $rug->replace;
        die $error if $error;
  }
}

=back

=head1 SEE ALSO

L<svc_acct>, L<FS::radius_group>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

