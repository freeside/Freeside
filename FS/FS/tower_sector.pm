package FS::tower_sector;
use base qw( FS::Record );

use Class::Load qw(load_class);
use File::Path qw(make_path);
use Data::Dumper;
use Cpanel::JSON::XS;

use strict;

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

=item db_high

The signal loss margin to treat as "high quality".

=item db_low

The signal loss margin to treat as "low quality".

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

=cut

sub insert {
  my $self = shift;
  my $error = $self->SUPER::insert;
  return $error if $error;

  if (scalar($self->need_fields_for_coverage) == 0) {
    $self->queue_generate_coverage;
  }
}

sub replace {
  my $self = shift;
  my $old = shift || $self->replace_old;
  my $regen_coverage = 0;
  if ( !$self->get('no_regen') ) {
    foreach (qw(height freq_mhz direction width downtilt
                v_width db_high db_low))
    {
      $regen_coverage = 1 if ($self->get($_) ne $old->get($_));
    }
  }

  my $error = $self->SUPER::replace($old);
  return $error if $error;

  if ($regen_coverage) {
    $self->queue_generate_coverage;
  }
}

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
    || $self->ut_numbern('db_high')
    || $self->ut_numbern('db_low')
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
    db_high   => 'High quality',
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
  my $need_fields = join(',', $self->need_fields_for_coverage);
  return "Sector needs fields $need_fields" if $need_fields;
  $self->set('no_regen', 1); # avoid recursion
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
  $job->update_statustext('0,generating map') if $job;
  my $sectornum = $param->{sectornum};
  my $sector = FS::tower_sector->by_key($sectornum)
    or die "sector $sectornum does not exist";
  $sector->set('no_regen', 1); # avoid recursion
  my $tower = $sector->tower;

  load_class('Map::Splat');

  # since this is still experimental, put it somewhere we can find later
  my $workdir = "$FS::UID::cache_dir/cache.$FS::UID::datasrc/" .
                "generate_coverage/sector$sectornum-". time;
  make_path($workdir);
  my $splat = Map::Splat->new(
    lon         => $tower->longitude,
    lat         => $tower->latitude,
    height      => ($sector->height || $tower->height || 0),
    freq        => $sector->freq_mhz,
    azimuth     => $sector->direction,
    h_width     => $sector->width,
    tilt        => $sector->downtilt,
    v_width     => $sector->v_width,
    db_levels   => [ $sector->db_low, $sector->db_high ],
    dir         => $workdir,
    #simplify    => 0.0004, # remove stairstepping in SRTM3 data?
  );
  $splat->calculate;

  my $box = $splat->box;
  foreach (qw(west east south north)) {
    $sector->set($_, $box->{$_});
  }
  $sector->set('image', $splat->png);
  my $error = $sector->replace;
  die $error if $error;

  foreach ($sector->sector_coverage) {
    $error = $_->delete;
    die $error if $error;
  }
  # XXX undecided whether Map::Splat should even do this operation
  # or how to store it
  # or anything else
  $DB::single = 1;
  my $data = decode_json( $splat->polygonize_json );
  for my $feature (@{ $data->{features} }) {
    my $db = $feature->{properties}{level};
    my $coverage = FS::sector_coverage->new({
      sectornum => $sectornum,
      db_loss   => $db,
      geometry  => encode_json($feature->{geometry})
    });
    $error = $coverage->insert;
  }

  die $error if $error;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::tower>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

