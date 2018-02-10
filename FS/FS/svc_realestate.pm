package FS::svc_realestate;
use base qw(FS::svc_Common);

use strict;
use warnings;
use vars qw($conf);

use FS::Record qw(qsearchs qsearch dbh);
use Tie::IxHash;

$FS::UID::callback{'FS::svc_realestate'} = sub {
  $conf = new FS::Conf;
};

=head1 NAME

FS::svc_realestate - Object methods for svc_realestate records

=head1 SYNOPSIS

  {...} TODO

=head1 DESCRIPTION

A FS::svc_realestate object represents a billable real estate trasnaction,
such as renting a home or office.

FS::svc_realestate inherits from FS::svc_Common.  The following fields are
currently supported:

=over 4

=item svcnum - primary key

=back

=head1 METHODS

=over 4

=item new HASHREF

Instantiates a new svc_realestate object.

=cut

sub table_info {
  tie my %fields, 'Tie::IxHash',
    svcnum      => 'Service',
    realestatenum => {
      type => 'select-realestate_unit',
      label => 'Real estate unit',
    };

  {
    name            => 'Real estate',
    name_plural     => 'Real estate services',
    longname_plural => 'Real estate services',
    display_weight  => 100,
    cancel_weight   => 100,
    fields          => \%fields,
  };
}

sub table {'svc_realestate'}

=item label

Returns a label formatted as:
  <location_title> <unit_title>

=cut

sub label {
  my $self = shift;
  my $unit = $self->realestate_unit;
  my $location = $self->realestate_location;

  return $location->location_title.' '.$unit->unit_title
    if $unit && $location;

  return $self->svcnum; # shouldn't happen
}


=item realestate_unit

Returns associated L<FS::realestate_unit>

=cut

sub realestate_unit {
  my $self = shift;

  return $self->get('_realestate_unit')
    if $self->get('_realestate_unit');

  return unless $self->realestatenum;

  my $realestate_unit = qsearchs(
    'realestate_unit',
    {realestatenum => $self->realestatenum}
  );

  $self->set('_realestate_unit', $realestate_unit);
  $realestate_unit;
}

=item realestate_location

Returns associated L<FS::realestate_location>

=cut

sub realestate_location {
  my $self = shift;

  my $realestate_unit = $self->realestate_unit;
  return unless $realestate_unit;

  $realestate_unit->location;
}

=item cust_svc

Returns associated L<FS::cust_svc>

=cut

sub cust_svc {
  qsearchs('cust_svc', { 'svcnum' => $_[0]->svcnum } );
}

=item search_sql

I have an unfounded suspicion this method serves no purpose in this context

=cut

# sub search_sql {die "search_sql called on FS::svc_realestate"}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=back 4

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;
