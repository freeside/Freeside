package FS::part_pkg_fcc_option;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use Storable qw(dclone);
use Tie::IxHash;

sub table { 'part_pkg_fcc_option'; }

=head1 NAME

FS::part_pkg_fcc_option - Object methods for part_pkg_fcc_option records

=head1 SYNOPSIS

  use FS::part_pkg_fcc_option;

  $record = new FS::part_pkg_fcc_option \%hash;
  $record = new FS::part_pkg_fcc_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_fcc_option object represents an option that classifies a
package definition on the FCC Form 477 report.  FS::part_pkg_fcc_option 
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item num

primary key

=item fccoptionname

A string identifying a report option, as an element of a static data
structure found within this module.  See the C<part> method.

=item pkgpart

L<FS::part_pkg> foreign key.

=item optionvalue

The value of the report option, as an integer.  Boolean options use 1 
and NULL.  Most other options have some kind of lookup table.

=back

=head1 METHODS

=over 4

=item check

Checks all fields to make sure this is a valid FCC option.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_alpha('fccoptionname')
    || $self->ut_number('pkgpart')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item media_types

Returns a Tie::IxHash hashref of the media type strings (which are not 
part of the report definition, per se) to arrayrefs of the technology 
codes included in each one.

=item technology_labels

Returns a hashref relating each technology code to a label.  Unlike the 
media type strings, the technology codes are part of the formal report
definition.

=cut

tie our %media_types, 'Tie::IxHash', (
  'Copper'          => [ 11, 12, 10, 20, 30 ],
  'Cable Modem'     => [ 41, 42, 40 ],
  'Fiber'           => [ 50 ],
  'Satellite'       => [ 60 ],
  'Fixed Wireless'  => [ 70 ],
  'Mobile Wireless' => [ 80, 81, 82, 83, 84, 85, 86, 87, 88 ],
  'Other'           => [ 90, 0 ],
);

our %technology_labels = (
      10 => 'Other ADSL',
      11 => 'ADSL2',
      12 => 'VDSL',
      20 => 'SDSL',
      30 => 'Other Copper Wireline',
      40 => 'Other Cable Modem',
      41 => 'Cable - DOCSIS 1, 1.1, 2.0',
      42 => 'Cable - DOCSIS 3.0',
      50 => 'Fiber',
      60 => 'Satellite',
      70 => 'Terrestrial Fixed Wireless',
      # mobile wireless
      80 => 'Mobile - WCDMA/UMTS/HSPA',
      81 => 'Mobile - HSPA+',
      82 => 'Mobile - EVDO/EVDO Rev A',
      83 => 'Mobile - LTE',
      84 => 'Mobile - WiMAX',
      85 => 'Mobile - CDMA',
      86 => 'Mobile - GSM',
      87 => 'Mobile - Analog',
      88 => 'Other Mobile',

      90 => 'Electric Power Line',
      0  => 'Other'
);

sub media_types {
  Storable::dclone(\%media_types);
}

sub technology_labels {
  +{ %technology_labels };
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

