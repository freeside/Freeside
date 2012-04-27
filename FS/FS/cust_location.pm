package FS::cust_location;
use base qw( FS::geocode_Mixin FS::Record );

use strict;
use vars qw( $import );
use Locale::Country;
use FS::UID qw( dbh );
use FS::Record qw( qsearch ); #qsearchs );
use FS::Conf;
use FS::prospect_main;
use FS::cust_main;
use FS::cust_main_county;

$import = 0;

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

=item district

Tax district code (optional)

=item disabled

Disabled flag; set to 'Y' to disable the location.

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

=cut

sub insert {
  my $self = shift;
  my $error = $self->SUPER::insert(@_);

  #false laziness with cust_main, will go away eventually
  my $conf = new FS::Conf;
  if ( !$error and $conf->config('tax_district_method') ) {

    my $queue = new FS::queue {
      'job' => 'FS::geocode_Mixin::process_district_update'
    };
    $error = $queue->insert( ref($self), $self->locationnum );

  }

  $error || '';
}

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;
  my $old = shift;
  $old ||= $self->replace_old;
  my $error = $self->SUPER::replace($old);

  #false laziness with cust_main, will go away eventually
  my $conf = new FS::Conf;
  if ( !$error and $conf->config('tax_district_method') 
    and $self->get('address1') ne $old->get('address1') ) {

    my $queue = new FS::queue {
      'job' => 'FS::geocode_Mixin::process_district_update'
    };
    $error = $queue->insert( ref($self), $self->locationnum );

  }

  $error || '';
}


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
    || $self->ut_coordn('latitude')
    || $self->ut_coordn('longitude')
    || $self->ut_enum('coord_auto', [ '', 'Y' ])
    || $self->ut_alphan('location_type')
    || $self->ut_textn('location_number')
    || $self->ut_enum('location_kind', [ '', 'R', 'B' ] )
    || $self->ut_alphan('geocode')
    || $self->ut_alphan('district')
  ;
  return $error if $error;

  $self->set_coord
    unless $import || ($self->latitude && $self->longitude);

  return "No prospect or customer!" unless $self->prospectnum || $self->custnum;
  return "Prospect and customer!"       if $self->prospectnum && $self->custnum;

  my $conf = new FS::Conf;
  return 'Location kind is required'
    if $self->prospectnum
    && $conf->exists('prospect_main-alt_address_format')
    && ! $self->location_kind;

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

Synonym for location_label

=cut

sub line {
  my $self = shift;
  $self->location_label;
}

=item has_ship_address

Returns false since cust_location objects do not have a separate shipping
address.

=cut

sub has_ship_address {
  '';
}

=item location_hash

Returns a list of key/value pairs, with the following keys: address1, address2,
city, county, state, zip, country, geocode, location_type, location_number,
location_kind.

=cut

=item move_to HASHREF

Takes a hashref with one or more cust_location fields.  Creates a duplicate 
of the existing location with all fields set to the values in the hashref.  
Moves all packages that use the existing location to the new one, then sets 
the "disabled" flag on the old location.  Returns nothing on success, an 
error message on error.

=cut

sub move_to {
  my $old = shift;
  my $hashref = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  my $error = '';

  my $new = FS::cust_location->new({
      $old->location_hash,
      'custnum'     => $old->custnum,
      'prospectnum' => $old->prospectnum,
      %$hashref
    });
  $error = $new->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error creating location: $error";
  }

  my @pkgs = qsearch('cust_pkg', { 
      'locationnum' => $old->locationnum,
      'cancel' => '' 
    });
  foreach my $cust_pkg (@pkgs) {
    $error = $cust_pkg->change(
      'locationnum' => $new->locationnum,
      'keep_dates'  => 1
    );
    if ( $error and not ref($error) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error moving pkgnum ".$cust_pkg->pkgnum.": $error";
    }
  }

  $old->disabled('Y');
  $error = $old->replace;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error disabling old location: $error";
  }

  $dbh->commit if $oldAutoCommit;
  return;
}

=item alternize

Attempts to parse data for location_type and location_number from address1
and address2.

=cut

sub alternize {
  my $self = shift;

  return '' if $self->get('location_type')
            || $self->get('location_number');

  my %parse;
  if ( 1 ) { #ikano, switch on via config
    { no warnings 'void';
      eval { 'use FS::part_export::ikano;' };
      die $@ if $@;
    }
    %parse = FS::part_export::ikano->location_types_parse;
  } else {
    %parse = (); #?
  }

  foreach my $from ('address1', 'address2') {
    foreach my $parse ( keys %parse ) {
      my $value = $self->get($from);
      if ( $value =~ s/(^|\W+)$parse\W+(\w+)\W*$//i ) {
        $self->set('location_type', $parse{$parse});
        $self->set('location_number', $2);
        $self->set($from, $value);
        return '';
      }
    }
  }

  #nothing matched, no changes
  $self->get('address2')
    ? "Can't parse unit type and number from address2"
    : '';
}

=item dealternize

Moves data from location_type and location_number to the end of address1.

=cut

sub dealternize {
  my $self = shift;

  #false laziness w/geocode_Mixin.pm::line
  my $lt = $self->get('location_type');
  if ( $lt ) {

    my %location_type;
    if ( 1 ) { #ikano, switch on via config
      { no warnings 'void';
        eval { 'use FS::part_export::ikano;' };
        die $@ if $@;
      }
      %location_type = FS::part_export::ikano->location_types;
    } else {
      %location_type = (); #?
    }

    $self->address1( $self->address1. ' '. $location_type{$lt} || $lt );
    $self->location_type('');
  }

  if ( length($self->location_number) ) {
    $self->address1( $self->address1. ' '. $self->location_number );
    $self->location_number('');
  }
 
  '';
}

=item location_label

Returns the label of the location object, with an optional site ID
string (based on the cust_location-label_prefix config option).

=cut

sub location_label {
  my $self = shift;
  my %opt = @_;
  my $conf = new FS::Conf;
  my $prefix = '';
  my $format = $conf->config('cust_location-label_prefix') || '';
  if ( $format eq 'CoStAg' ) {
    my $cust_or_prospect;
    if ( $self->custnum ) {
      $cust_or_prospect = FS::cust_main->by_key($self->custnum);
    }
    elsif ( $self->prospectnum )  {
      $cust_or_prospect = FS::prospect_main->by_key($self->prospectnum);
    }
    my $agent = $conf->config('cust_location-agent_code', 
                  $cust_or_prospect->agentnum)
                || $cust_or_prospect->agent->agent;
    # else this location is invalid
    $prefix = uc( join('',
        $self->country,
        ($self->state =~ /^(..)/),
        ($agent =~ /^(..)/),
        sprintf('%05d', $self->locationnum)
    ) );
  }
  $prefix .= ($opt{join_string} ||  ': ') if $prefix;
  $prefix . $self->SUPER::location_label(%opt);
}

=back

=head1 BUGS

Not yet used for cust_main billing and shipping addresses.

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_pkg>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

