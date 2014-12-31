package FS::deploy_zone;

use strict;
use base qw( FS::o2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs dbh );
use Storable qw(thaw);
use MIME::Base64;

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

=item dbaname

The name under which service is marketed in this zone.  If null, will 
default to the agent name.

=item zonetype

The way the zone geography is defined: "B" for a list of census blocks
(used by the FCC for fixed broadband service), "P" for a polygon (for 
mobile services).  See L<FS::deploy_zone_block> and L<FS::deploy_zone_vertex>.

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
  my $error = $self->process_o2m(
    'table'   => $self->element_table,
    'num_col' => 'zonenum',
    'fields'  => 'zonenum',
    'params'  => {},
  ) || $self->SUPER::delete(@_);
  
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

=item element_table

Returns the name of the table that contains the zone's elements (blocks or
vertices).

=cut

sub element_table {
  my $self = shift;
  if ($self->zonetype eq 'B') {
    return 'deploy_zone_block';
  } elsif ( $self->zonetype eq 'P') {
    return 'deploy_zone_vertex';
  } else {
    die 'unknown zonetype';
  }
}

=item deploy_zone_block

Returns the census block records in this zone, in order by census block
number.  Only appropriate to block-type zones.

=item deploy_zone_vertex

Returns the vertex records for this zone, in order by sequence number.  Only
appropriate to polygon-type zones.

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

=back

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
        
=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

