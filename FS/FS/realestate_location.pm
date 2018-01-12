package FS::realestate_location;
use strict;
use warnings;
use Carp qw(croak);

use base 'FS::Record';

use FS::Record qw(qsearchs qsearch);

=head1 NAME

FS::realestate_location - Object representing a realestate_location record

=head1 SYNOPSIS

  use FS::realestate_location;

  $location = new FS::realestate_location \%values;
  $location = new FS::realestate_location {
    agentnum          => 1,
    location_title    => 'Superdome',
    address1          => '1500 Sugar Bowl Dr',
    city              => 'New Orleans',
    state             => 'LA',
    zip               => '70112',
  };

  $error = $location->insert;
  $error = $new_loc->replace($location);
  $error = $record->check;

  $error = $location->add_unit('Box Seat No. 42');
  @units = $location->units;

=head1 DESCRIPTION

An FS::realestate_location object represents a location for one or more
FS::realestate_unit objects.  Expected to contain at least one unit, as only
realestate_unit objects are assignable to packages via
L<FS::svc_realestate>.

FS::realestate_location inherits from FS::Record.

The following fields are currently supported:

=over 4

=item realestatelocnum

=item agentnum

=item location_title

=item address1 (optional)

=item address2 (optional)

=item city (optional)

=item state (optional)

=item zip (optional)

=item disabled

=back

=head1 METHODS

=over 4

=item new HASHREF (see L<FS::Record>)

=cut

sub table {'realestate_location';}

=item insert (see L<FS::Record>)

=item delete

  FS::realestate_location records should never be deleted, only disabled

=cut

sub delete {
  # Once this record has been associated with a customer in any way, it
  # should not be deleted.  todo perhaps, add a is_deletable function that
  # checks if the record has ever actually been used, and allows deletion
  # if it hasn't.  (entered in error, etc).
  croak "FS::realestate_location records should never be deleted";
}

=item replace OLD_RECORD (see L<FS::Record>)

=item check (see L<FS::Record>)

=item agent

Returns the associated agent

=cut

sub agent {
  my $self = shift;
  return undef unless $self->agentnum;
  return exists $self->{agent}
  ? $self->{agent}
  : $self->{agent} = qsearchs('agent', {agentnum => $self->agentnum} );
}


=item add_unit UNIT_TITLE

Create an associated L<FS::realestate_unit> record

=cut

sub add_unit {
  my ($self, $unit_title) = @_;
  croak "add_unit() requires a \$unit_title parameter" unless $unit_title;

  if (
    qsearchs('realestate_unit',{
      realestatelocnum => $self->realestatelocnum,
      unit_title => $unit_title,
    })
  ) {
    return "Unit Title ($unit_title) has already been used for location (".
      $self->location_title.")";
  }

  my $unit = FS::realestate_unit->new({
    realestatelocnum => $self->realestatelocnum,
    agentnum         => $self->agentnum,
    unit_title       => $unit_title,
  });
  my $err = $unit->insert;
  die "Error creating FS::realestate_new record: $err" if $err;

  return;
}


=item units

Returns all units associated with this location

=cut

sub units {
  my $self = shift;
  return qsearch(
    'realestate_unit',
    {realestatelocnum => $self->realestatelocnum}
  );
}


=head1 SUBROUTINES

=over 4

=cut




=back

=head1 SEE ALSO

L<FS::record>, L<FS::realestate_unit>, L<FS::svc_realestate>

=cut

1;
