package FS::realestate_unit;
use strict;
use warnings;
use Carp qw(croak);

use base 'FS::Record';
use FS::Record qw(qsearch qsearchs);

=head1 NAME

FS::realestate_unit - Object representing a realestate_unit record

=head1 SYNOPSIS

  use FS::realestate_unit;

  $record = new FS:realestate_unit  \%values;
  $record = new FS::realestate_unit {
    realestatelocnum => 42,
    agentnum         => 1,
    unit_title       => 'Ste 404',
  };

  $error = $record->insert;
  $error = $new_rec->replace($record)
  $error = $record->check;

  $location = $record->location;

=head1 DESCRIPTION

An FS::realestate_unit object represents an invoicable unit of real estate.
Object may represent a single property, such as a rental house.  It may also
represent a group of properties sharing a common address or identifier, such
as a shopping mall, apartment complex, or office building, concert hall.

A FS::realestate_unit object must be associated with a FS::realestate_location

FS::realestate_unit inherits from FS::Record.

The following fields are currently supported:

=over 4

=item realestatenum

=item realestatelocnum

=item agentnum

=item unit_title

=item disabled

=back

=head1 METHODS

=over 4

=item new HASHREF (see L<FS::Record>)

=cut

sub table {'realestate_unit';}

=item insert (see L<FS::Record>)

=item delete

  FS::realestate_unit records should never be deleted, only disabled

=cut

sub delete {
  # Once this record has been associated with a customer in any way, it
  # should not be deleted.  todo perhaps, add a is_deletable function that
  # checks if the record has ever actually been used, and allows deletion
  # if it hasn't.  (entered in error, etc).
  croak "FS::realestate_unit records should never be deleted";
}


=item replace OLD_RECORD (see L<FS::Record>)

=item check (see L<FS::Record>)

=item agent

Returns the associated agent, if any, for this object

=cut

sub agent {
  my $self = shift;
  return undef unless $self->agentnum;
  return qsearchs('agent', {agentnum => $self->agentnum} );
}

=item location

  Return the associated FS::realestate_location object

=cut

sub location {
  my $self = shift;
  return $self->{location} if exists $self->{location};
  return $self->{location} = qsearchs(
    'realestate_location',
    {realestatelocnum => $self->realestatelocnum}
  );
}

=back

=item custnum

Pull the assigned custnum for this unit, if provisioned

=cut

sub custnum {
  my $self = shift;
  return $self->{custnum}
    if $self->{custnum};

  # select cust_pkg.custnum
  # from svc_realestate
  # LEFT JOIN cust_svc ON svc_realestate.svcnum = cust_svc.svcnum
  # LEFT JOIN cust_pkg ON cust_svc.pkgnum = cust_pkg.pkgnum
  # WHERE svc_realestate.realestatenum = $realestatenum

  my $row = qsearchs({
    select    => 'cust_pkg.custnum',
    table     => 'svc_realestate',
    addl_from => 'LEFT JOIN cust_svc ON svc_realestate.svcnum = cust_svc.svcnum '
               . 'LEFT JOIN cust_pkg ON cust_svc.pkgnum = cust_pkg.pkgnum ',
    extra_sql => 'WHERE svc_realestate.realestatenum = '.$self->realestatenum,
  });

  return
    unless $row && $row->custnum;

  return $self->{custnum} = $row->custnum;
}

=head1 SUBROUTINES

=over 4

=cut


=back

=head1 SEE ALSO

L<FS::record>, L<FS::realestate_location>, L<FS::svc_realestate>

=cut

1;
