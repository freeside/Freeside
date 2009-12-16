package FS::cust_location;

use strict;
use base qw( FS::Record );
use Locale::Country;
use FS::Record qw( qsearch ); #qsearchs );
use FS::cust_main;
use FS::cust_main_county;

=head1 NAME

FS::cust_location - Object methods for cust_location records

=head1 SYNOPSIS

  use FS::cust_location;

  $record = new FS::cust_location \%hash;
  $record = new FS::cust_location { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_location object represents a customer location.  FS::cust_location
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item locationnum

primary key

=item custnum

custnum

=item address1

Address line one (required)

=item address2

Address line two (optional)

=item city

City

=item county

County (optional, see L<FS::cust_main_county>)

=item state

State (see L<FS::cust_main_county>)

=item zip

Zip

=item country

Country (see L<FS::cust_main_county>)

=item geocode

Geocode

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new location.  To add the location to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_location'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid location.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

#some false laziness w/cust_main, but since it should eventually lose these
#fields anyway...
sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('locationnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('county')
    || $self->ut_textn('state')
    || $self->ut_country('country')
    || $self->ut_zip('zip', $self->country)
    || $self->ut_alphan('geocode')
  ;
  return $error if $error;

  unless ( qsearch('cust_main_county', {
    'country' => $self->country,
    'state'   => '',
   } ) ) {
    return "Unknown state/county/country: ".
      $self->state. "/". $self->county. "/". $self->country
      unless qsearch('cust_main_county',{
        'state'   => $self->state,
        'county'  => $self->county,
        'country' => $self->country,
      } );
  }

  $self->SUPER::check;
}

=item country_full

Returns this locations's full country name

=cut

sub country_full {
  my $self = shift;
  code2country($self->country);
}

=item line

Returns this location on one line

=cut

sub line {
  my $self = shift;
  my $cydefault = FS::conf->new->config('countrydefault') || 'US';

  my $line =       $self->address1;
  $line   .= ', '. $self->address2              if $self->address2;
  $line   .= ', '. $self->city;
  $line   .= ' ('. $self->county. ' county)'    if $self->county;
  $line   .= ', '. $self->state                 if $self->state;
  $line   .= '  '. $self->zip                   if $self->zip;
  $line   .= '  '. code2country($self->country) if $self->country ne $cydefault;

  $line;
}

=item line_short

Returns this location on one line in a shortened form

=cut

# configurable?

sub line_short {
  my $self = shift;
  my $cydefault = FS::conf->new->config('countrydefault') || 'US';

  my $line =       $self->address1;
  #$line   .= ', '. $self->address2              if $self->address2;
  $line   .= ', '. $self->city;
  $line   .= ', '. $self->state                 if $self->state;
  $line   .= '  '. $self->zip                   if $self->zip;
  $line   .= '  '. code2country($self->country) if $self->country ne $cydefault;

  $line;
}

=item location_label_short

Synonym for line_short

=cut

sub location_label_short {
  my $self = shift;
  $self->line_short;
}

=back

=head1 BUGS

Not yet used for cust_main billing and shipping addresses.

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_pkg>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

