package FS::deploy_zone;

use strict;
use base qw( FS::o2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs dbh );
use Storable qw(thaw);
use MIME::Base64;

use Cpanel::JSON::XS;
use LWP::UserAgent;
use HTTP::Request::Common;

# update this in 2020, along with the URL for the TIGERweb service
our $CENSUS_YEAR = 2010;

=head1 NAME

FS::deploy_zone - Object methods for deploy_zone records

=head1 SYNOPSIS

  use FS::deploy_zone;

  $record = new FS::deploy_zone \%hash;
  $record = new FS::deploy_zone { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::deploy_zone object represents a geographic zone where a certain kind
of service is available.  Currently we store this information to generate
the FCC Form 477 deployment reports, but it may find other uses later.

FS::deploy_zone inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item zonenum

primary key

=item description

Optional text describing the zone.

=item agentnum

The agent that serves this zone.

=item censusyear

The census map year for which this zone was last updated. May be null for
zones that contain no census blocks (mobile zones, or fixed zones that haven't
had their block lists filled in yet).

=item dbaname

The name under which service is marketed in this zone.  If null, will 
default to the agent name.

=item zonetype

The way the zone geography is defined: "B" for a list of census blocks
(used by the FCC for fixed broadband service), "P" for a polygon (for 
mobile services).  See L<FS::deploy_zone_block> and L<FS::deploy_zone_vertex>.
Note that block-type zones are still allowed to have a vertex list, for
use by the map editor.

=item technology

The FCC technology code for the type of service available.

=item spectrum

For mobile service zones, the FCC code for the RF band.

=item adv_speed_up

For broadband, the advertised upstream bandwidth in the zone.  If multiple
speed tiers are advertised, use the highest.

=item adv_speed_down

For broadband, the advertised downstream bandwidth in the zone.

=item cir_speed_up

For broadband, the contractually guaranteed upstream bandwidth, if that type
of service is sold.

=item cir_speed_down

For broadband, the contractually guaranteed downstream bandwidth, if that 
type of service is sold.

=item is_consumer

'Y' if this service is sold for consumer/household use.

=item is_business

'Y' if this service is sold to business or institutional use.  Not mutually
exclusive with is_consumer.

=item is_broadband

'Y' if this service includes broadband Internet.

=item is_voice

'Y' if this service includes voice communication.

=item active_date

The date this zone became active.

=item expire_date

The date this zone became inactive, if any.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new zone.  To add the zone to the database, see L<"insert">.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'deploy_zone'; }

=item insert ELEMENTS

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

sub delete {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  # clean up linked records
  my $self = shift;
  my $error;
  foreach (qw(deploy_zone_block deploy_zone_vertex)) {
    $error ||= $self->process_o2m(
      'table'   => $_,
      'num_col' => 'zonenum',
      'fields'  => 'zonenum',
      'params'  => {},
    );
  }
  $error ||= $self->SUPER::delete(@_);
  
  if ($error) {
    dbh->rollback if $oldAutoCommit;
    return $error;
  }
  '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid zone record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('zonenum')
    || $self->ut_text('description')
    || $self->ut_number('agentnum')
    || $self->ut_numbern('censusyear')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_textn('dbaname')
    || $self->ut_enum('zonetype', [ 'B', 'P' ])
    || $self->ut_number('technology')
    || $self->ut_numbern('spectrum')
    || $self->ut_decimaln('adv_speed_up', 3)
    || $self->ut_decimaln('adv_speed_down', 3)
    || $self->ut_decimaln('cir_speed_up', 3)
    || $self->ut_decimaln('cir_speed_down', 3)
    || $self->ut_flag('is_consumer')
    || $self->ut_flag('is_business')
    || $self->ut_flag('is_broadband')
    || $self->ut_flag('is_voice')
    || $self->ut_numbern('active_date')
    || $self->ut_numbern('expire_date')
  ;
  return $error if $error;

  foreach(qw(adv_speed_down adv_speed_up cir_speed_down cir_speed_up)) {
    if ($self->get('is_broadband')) {
      if (!$self->get($_)) {
        $self->set($_, 0);
      }
    } else {
      $self->set($_, '');
    }
  }
  if (!$self->get('active_date')) {
    $self->set('active_date', time);
  }

  $self->SUPER::check;
}

=item deploy_zone_block

Returns the census block records in this zone, in order by census block
number.  Only appropriate to block-type zones.

=item deploy_zone_vertex

Returns the vertex records for this zone, in order by sequence number.

=cut

sub deploy_zone_block {
  my $self = shift;
  qsearch({
      table     => 'deploy_zone_block',
      hashref   => { zonenum => $self->zonenum },
      order_by  => ' ORDER BY censusblock',
  });
}

sub deploy_zone_vertex {
  my $self = shift;
  qsearch({
      table     => 'deploy_zone_vertex',
      hashref   => { zonenum => $self->zonenum },
      order_by  => ' ORDER BY vertexnum',
  });
}

=item vertices_json

Returns the vertex list for this zone, as a JSON string of

[ [ latitude0, longitude0 ], [ latitude1, longitude1 ] ... ]

=cut

sub vertices_json {
  my $self = shift;
  my @vertices = map { [ $_->latitude, $_->longitude ] } $self->deploy_zone_vertex;
  encode_json(\@vertices);
}

=head2 SUBROUTINES

=over 4

=item process_batch_import JOB, PARAMS

=cut

sub process_batch_import {
  eval {
    use FS::deploy_zone_block;
    use FS::deploy_zone_vertex;
  };
  my $job = shift;
  my $param = shift;
  if (!ref($param)) {
    $param = thaw(decode_base64($param));
  }

  # even if creating a new zone, the deploy_zone object should already
  # be inserted by this point
  my $zonenum = $param->{zonenum}
    or die "zonenum required";
  my $zone = FS::deploy_zone->by_key($zonenum)
    or die "deploy_zone #$zonenum not found";
  my $opt;
  if ( $zone->zonetype eq 'B' ) {
    $opt = { 'table'    => 'deploy_zone_block',
             'params'   => [ 'zonenum', 'censusyear' ],
             'formats'  => { 'plain' => [ 'censusblock' ] },
             'default_csv' => 1,
           };
    $job->update_statustext('1,Inserting census blocks');
  } elsif ( $zone->zonetype eq 'P' ) {
    $opt = { 'table'    => 'deploy_zone_vertex',
             'params'   => [ 'zonenum' ],
             'formats'  => { 'plain' => [ 'latitude', 'longitude' ] },
             'default_csv' => 1,
           };
  } else {
    die "don't know how to import to zonetype ".$zone->zonetype;
  }

  FS::Record::process_batch_import( $job, $opt, $param );

}

=item process_block_lookup JOB, ZONENUM

Look up all the census blocks in the zone's footprint, and insert them.
This will replace any existing block list.

=cut

sub process_block_lookup {
  my $job = shift;
  my $param = shift;
  if (!ref($param)) {
    $param = thaw(decode_base64($param));
  }
  my $zonenum = $param->{zonenum};
  my $zone = FS::deploy_zone->by_key($zonenum)
    or die "zone $zonenum not found\n";

  # wipe the existing list of blocks
  my $error = $zone->process_o2m(
    'table'   => 'deploy_zone_block',
    'num_col' => 'zonenum', 
    'fields'  => 'zonenum',
    'params'  => {},
  );
  die $error if $error;

  $job->update_statustext('0,querying census database') if $job;

  # negotiate the rugged jungle trails of the ArcGIS REST protocol:
  # 1. unlike most places, longitude first.
  my @zone_vertices = map { [ $_->longitude, $_->latitude ] }
    $zone->deploy_zone_vertex;

  return if scalar(@zone_vertices) < 3; # then don't bother

  # 2. package this as "rings", inside a JSON geometry object
  # 3. announce loudly and frequently that we are using spatial reference 
  #    4326, "true GPS coordinates"
  my $geometry = encode_json({
      'rings' => [ \@zone_vertices ],
      'wkid'  => 4326,
  });

  my %query = (
    f               => 'json', # duh
    geometry        => $geometry,
    geometryType    => 'esriGeometryPolygon', # as opposed to a bounding box
    inSR            => 4326,
    outSR           => 4326,
    spatialRel      => 'esriSpatialRelIntersects', # the test to perform
    outFields       => 'OID,GEOID',
    returnGeometry  => 'false',
    orderByFields   => 'OID',
  );
  my $url = 'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Tracts_Blocks/MapServer/12/query';
  my $ua = LWP::UserAgent->new;

  # first find out how many of these we're dealing with
  my $response = $ua->request(
    POST $url, Content => [
      %query,
      returnCountOnly => 1,
    ]
  );
  die $response->status_line unless $response->is_success;
  my $data = decode_json($response->content);
  # their error messages are mostly useless, but don't just blindly continue
  die $data->{error}{message} if $data->{error};

  my $count = $data->{count};
  my $inserted = 0;

  #warn "Census block lookup: $count\n";

  # we have to do our own pagination on this, because the census bureau
  # doesn't support resultOffset (maybe they don't have ArcGIS 10.3 yet).
  # that's why we're ordering by OID, it's globally unique
  my $last_oid = 0;
  my $done = 0;
  while (!$done) {
    $response = $ua->request(
      POST $url, Content => [
        %query,
        where => "OID>$last_oid",
      ]
    );
    die $response->status_line unless $response->is_success;
    $data = decode_json($response->content);
    die $data->{error}{message} if $data->{error};

    foreach my $feature (@{ $data->{features} }) {
      my $geoid = $feature->{attributes}{GEOID}; # the prize
      my $block = FS::deploy_zone_block->new({
          zonenum     => $zonenum,
          censusblock => $geoid
      });
      $error = $block->insert;
      die "$error (inserting census block $geoid)" if $error;

      $inserted++;
      if ($job and $inserted % 100 == 0) {
        my $percent = sprintf('%.0f', $inserted / $count * 100);
        $job->update_statustext("$percent,creating block records");
      }
    }

    #warn "Inserted $inserted records\n";
    $last_oid = $data->{features}[-1]{attributes}{OID};
    $done = 1 unless $data->{exceededTransferLimit};
  }

  $zone->set('censusyear', $CENSUS_YEAR);  
  $error = $zone->replace;
  warn "$error (updating zone census year)" if $error; # whatever, continue

  return;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

