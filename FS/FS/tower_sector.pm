package FS::tower_sector;

use Class::Load qw(load_class);
use Data::Dumper;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::tower;
use FS::svc_broadband;

=head1 NAME

FS::tower_sector - Object methods for tower_sector records

=head1 SYNOPSIS

  use FS::tower_sector;

  $record = new FS::tower_sector \%hash;
  $record = new FS::tower_sector { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tower_sector object represents a tower sector.  FS::tower_sector
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item sectornum

primary key

=item towernum

towernum

=item sectorname

sectorname

=item ip_addr

ip_addr

=item height

The height of this antenna on the tower, measured from ground level. This
plus the tower's altitude should equal the height of the antenna above sea
level.

=item freq_mhz

The band center frequency in MHz.

=item direction

The antenna beam direction in degrees from north.

=item width

The -3dB horizontal beamwidth in degrees.

=item downtilt

The antenna beam elevation in degrees below horizontal.

=item v_width

The -3dB vertical beamwidth in degrees.

=item margin

The signal loss margin allowed on the sector, in dB. This is normally
transmitter EIRP minus receiver sensitivity.

=item image 

The coverage map, as a PNG.

=item west, east, south, north

The coordinate boundaries of the coverage map.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new sector.  To add the sector to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'tower_sector'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  #not the most efficient, not not awful, and its not like deleting a sector
  # with customers is a common operation
  return "Can't delete a sector with customers" if $self->svc_broadband;

  $self->SUPER::delete;
}

=item check

Checks all fields to make sure this is a valid sector.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('sectornum')
    || $self->ut_number('towernum', 'tower', 'towernum')
    || $self->ut_text('sectorname')
    || $self->ut_textn('ip_addr')
    || $self->ut_floatn('height')
    || $self->ut_numbern('freq_mhz')
    || $self->ut_numbern('direction')
    || $self->ut_numbern('width')
    || $self->ut_numbern('v_width')
    || $self->ut_numbern('downtilt')
    || $self->ut_floatn('sector_range')
    || $self->ut_numbern('margin')
    || $self->ut_anything('image')
    || $self->ut_sfloatn('west')
    || $self->ut_sfloatn('east')
    || $self->ut_sfloatn('south')
    || $self->ut_sfloatn('north')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item tower

Returns the tower for this sector, as an FS::tower object (see L<FS::tower>).

=cut

sub tower {
  my $self = shift;
  qsearchs('tower', { 'towernum'=>$self->towernum } );
}

=item description

Returns a description for this sector including tower name.

=cut

sub description {
  my $self = shift;
  if ( $self->sectorname eq '_default' ) {
    $self->tower->towername
  }
  else {
    $self->tower->towername. ' sector '. $self->sectorname
  }
}

=item svc_broadband

Returns the services on this tower sector.

=cut

sub svc_broadband {
  my $self = shift;
  qsearch('svc_broadband', { 'sectornum' => $self->sectornum });
}

=item need_fields_for_coverage

Returns a list of required fields for the coverage map that aren't yet filled.

=cut

sub need_fields_for_coverage {
  my $self = shift;
  my $tower = $self->tower;
  my %fields = (
    height    => 'Height',
    freq_mhz  => 'Frequency',
    direction => 'Direction',
    downtilt  => 'Downtilt',
    width     => 'Horiz. width',
    v_width   => 'Vert. width',
    margin    => 'Signal margin',
    latitude  => 'Latitude',
    longitude => 'Longitude',
  );
  my @need;
  foreach (keys %fields) {
    if ($self->get($_) eq '' and $tower->get($_) eq '') {
      push @need, $fields{$_};
    }
  }
  @need;
}

=item queue_generate_coverage

Starts a job to recalculate the coverage map.

=cut

sub queue_generate_coverage {
  my $self = shift;
  if ( length($self->image) > 0 ) {
    foreach (qw(image west south east north)) {
      $self->set($_, '');
    }
    my $error = $self->replace;
    return $error if $error;
  }
  my $job = FS::queue->new({
      job => 'FS::tower_sector::process_generate_coverage',
  });
  $job->insert('_JOB', { sectornum => $self->sectornum});
}

=back

=head1 SUBROUTINES

=over 4

=item process_generate_coverage JOB, PARAMS

Queueable routine to fetch the sector coverage map from the tower mapping
server and store it. Highly experimental. Requires L<Map::Splat> to be
installed.

PARAMS must include 'sectornum'.

=cut

sub process_generate_coverage {
  my $job = shift;
  my $param = shift;
  warn Dumper($param);
  $job->update_statustext('0,generating map');
  my $sectornum = $param->{sectornum};
  my $sector = FS::tower_sector->by_key($sectornum);
  my $tower = $sector->tower;

  load_class('Map::Splat');
  my $splat = Map::Splat->new(
    lon         => $tower->longitude,
    lat         => $tower->latitude,
    height      => ($sector->height || $tower->height || 0),
    freq        => $sector->freq_mhz,
    azimuth     => $sector->direction,
    h_width     => $sector->width,
    tilt        => $sector->downtilt,
    v_width     => $sector->v_width,
    max_loss    => $sector->margin,
    min_loss    => $sector->margin - 80,
  );
  $splat->calculate;

  my $box = $splat->box;
  foreach (qw(west east south north)) {
    $sector->set($_, $box->{$_});
  }
  $sector->set('image', $splat->mask);
  # mask returns a PNG where everything below max_loss is solid colored,
  # and everything above it is transparent. More useful for our purposes.
  my $error = $sector->replace;
  die $error if $error;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::tower>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

