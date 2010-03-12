package FS::cust_location;

use strict;
use base qw( FS::Record );
use Locale::Country;
use FS::Record qw( qsearch ); #qsearchs );
use FS::prospect_main;
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
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum')
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum')
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

  return "No prospect or customer!" unless $self->prospectnum || $self->custnum;
  return "Prospect and customer!"       if $self->prospectnum && $self->custnum;

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

=item location_label [ OPTION => VALUE ... ]

Returns the label of the service location for this customer.

Options are

=over 4

=item join_string

used to separate the address elements (defaults to ', ')

=item escape_function


a callback used for escaping the text of the address elements

=back

=cut

# false laziness with FS::cust_main::location_label

sub location_label {
  my $self = shift;
  my %opt = @_;

  my $separator = $opt{join_string} || ', ';
  my $escape = $opt{escape_function} || sub{ shift };
  my $ds = $opt{double_space} || '  ';
  my $line = '';
  my $cydefault =
    $opt{'countrydefault'} || FS::Conf->new->config('countrydefault') || 'US';
  my $prefix = '';

  my $notfirst = 0;
  foreach (qw ( address1 address2 ) ) {
    my $method = "$prefix$_";
    $line .= ($notfirst ? $separator : ''). &$escape($self->$method)
      if $self->$method;
    $notfirst++;
  }
  $notfirst = 0;
  foreach (qw ( city county state zip ) ) {
    my $method = "$prefix$_";
    if ( $self->$method ) {
      $line .= ($notfirst ? ($method eq 'zip' ? $ds : ' ') : $separator);
      $line .= '(' if $method eq 'county';
      $line .= &$escape($self->$method);
      $line .= ')' if $method eq 'county';
      $notfirst++;
    }
    $line .= ',' if $method eq 'county';
  }
  $line .= $separator. &$escape(code2country($self->country))
    if $self->country ne $cydefault;

  $line;
}

=item line

Synonym for location_label

=cut

sub line {
  my $self = shift;
  $self->location_label;
}

=item location_hash

Returns a list of key/value pairs, with the following keys: address1, adddress2,
city, county, state, zip, country.

=cut

#geocode?  not yet set

sub location_hash {
  my $self = shift;
  map { $_ => $self->$_ } qw( address1 address2 city county state zip country );
}

=back

=head1 BUGS

Not yet used for cust_main billing and shipping addresses.

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_pkg>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

