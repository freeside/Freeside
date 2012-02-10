package FS::tower;

use strict;
use base qw( FS::o2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::tower_sector;
use List::Util qw( max );

=head1 NAME

FS::tower - Object methods for tower records

=head1 SYNOPSIS

  use FS::tower;

  $record = new FS::tower \%hash;
  $record = new FS::tower { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tower object represents a tower.  FS::tower inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item towernum

primary key

=item towername

Tower name

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tower.  To add the tower to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'tower'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid tower.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('towernum')
    || $self->ut_text('towername')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item default_sector

Returns the default sector.

=cut

sub default_sector {
  my $self = shift;
  qsearchs('tower_sector', { towernum => $self->towernum,
                             sectorname => '_default' });
}

=item tower_sector

Returns the sectors of this tower, as FS::tower_sector objects (see
L<FS::tower_sector>), except for the default sector.

=cut

sub tower_sector {
  my $self = shift;
  qsearch({
    'table'    => 'tower_sector',
    'hashref'  => { 'towernum'    => $self->towernum,
                    'sectorname'  => { op => '!=', value => '_default' },
                  },
    'order_by' => 'ORDER BY sectorname',
  });
}

=item process_o2m

Wrapper for the default method (see L<FS::o2m_Common>) to manage the 
default sector.

=cut

sub process_o2m {
  my $self = shift;
  my %opt = @_;
  my $params = $opt{params};

  # Adjust to make sure our default sector is in the list.
  my $default_sector = $self->default_sector
    or warn "creating default sector for tower ".$self->towernum."\n";
  my $idx = max(0, map { $_ =~ /^sectornum(\d+)$/ ? $1 : 0 } keys(%$params));
  $idx++; # append to the param list
  my $prefix = "sectornum$idx";
  # empty sectornum will create the default sector if it doesn't exist yet
  $params->{$prefix} = $default_sector ? $default_sector->sectornum : '';
  $params->{$prefix.'_sectorname'} = '_default';
  $params->{$prefix.'_ip_addr'} = $params->{'default_ip_addr'} || '';

  $self->SUPER::process_o2m(%opt);
}

sub _upgrade_data {
  # Create default sectors for any tower that doesn't have one.
  # Shouldn't do any harm if they're missing, but just for completeness.
  my $class = shift;
  foreach my $tower (qsearch('tower',{})) {
    next if $tower->default_sector;
    my $sector = FS::tower_sector->new({
        towernum => $tower->towernum,
        sectorname => '_default',
        ip_addr => '',
    });
    my $error = $sector->insert;
    die "error creating default sector: $error\n" if $error;
  }
  '';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::tower_sector>, L<FS::svc_broadband>, L<FS::Record>

=cut

1;

