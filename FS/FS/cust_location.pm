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
  my $conf = new FS::Conf;

  if ( $self->censustract ) {
    $self->set('censusyear' => $conf->config('census_year') || 2012);
  }

  my $error = $self->SUPER::insert(@_);

  #false laziness with cust_main, will go away eventually
  if ( !$import and !$error and $conf->config('tax_district_method') ) {

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
  # the following fields are immutable
  foreach (qw(address1 address2 city state zip country)) {
    if ( $self->$_ ne $old->$_ ) {
      return "can't change cust_location field $_";
    }
  }

  $self->SUPER::replace($old);
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
  my $conf = new FS::Conf;

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
    || (!$import && $self->ut_zip('zip', $self->country))
    || $self->ut_coordn('latitude')
    || $self->ut_coordn('longitude')
    || $self->ut_enum('coord_auto', [ '', 'Y' ])
    || $self->ut_alphan('location_type')
    || $self->ut_textn('location_number')
    || $self->ut_enum('location_kind', [ '', 'R', 'B' ] )
    || $self->ut_alphan('geocode')
    || $self->ut_alphan('district')
    || $self->ut_numbern('censusyear')
  ;
  return $error if $error;
  if ( $self->censustract ne '' ) {
    $self->censustract =~ /^\s*(\d{9})\.?(\d{2})\s*$/
      or return "Illegal census tract: ". $self->censustract;

    $self->censustract("$1.$2");
  }

  if ( $conf->exists('cust_main-require_address2') and 
       !$self->ship_address2 =~ /\S/ ) {
    return "Unit # is required";
  }

  $self->set_coord
    unless $import || ($self->latitude && $self->longitude);

  # tricky...we have to allow for the customer to not be inserted yet
  return "No prospect or customer!" unless $self->prospectnum 
                                        || $self->custnum
                                        || $self->get('custnum_pending');
  return "Prospect and customer!"       if $self->prospectnum && $self->custnum;

  return 'Location kind is required'
    if $self->prospectnum
    && $conf->exists('prospect_main-alt_address_format')
    && ! $self->location_kind;

  unless ( $import or qsearch('cust_main_county', {
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

=item disable_if_unused

Sets the "disabled" flag on the location if it is no longer in use as a 
prospect location, package location, or a customer's billing or default
service address.

=cut

sub disable_if_unused {

  my $self = shift;
  my $locationnum = $self->locationnum;
  return '' if FS::cust_main->count('bill_locationnum = '.$locationnum)
            or FS::cust_main->count('ship_locationnum = '.$locationnum)
            or FS::contact->count(      'locationnum  = '.$locationnum)
            or FS::cust_pkg->count('cancel IS NULL AND 
                                         locationnum  = '.$locationnum)
          ;
  $self->disabled('Y');
  $self->replace;

}

=item move_to

Takes a new L<FS::cust_location> object.  Moves all packages that use the 
existing location to the new one, then sets the "disabled" flag on the old
location.  Returns nothing on success, an error message on error.

=cut

sub move_to {
  my $old = shift;
  my $new = shift;

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

  if ( !$new->locationnum ) {
    $error = $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error creating location: $error";
    }
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

  $error = $old->disable_if_unused;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error disabling old location: $error";
  }

  $dbh->commit if $oldAutoCommit;
  '';
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
  my $cust_or_prospect;
  if ( $self->custnum ) {
    $cust_or_prospect = FS::cust_main->by_key($self->custnum);
  }
  elsif ( $self->prospectnum ) {
    $cust_or_prospect = FS::prospect_main->by_key($self->prospectnum);
  }

  if ( $format eq 'CoStAg' ) {
    my $agent = $conf->config('cust_main-custnum-display_prefix',
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
  elsif ( $self->custnum and 
          $self->locationnum == $cust_or_prospect->ship_locationnum ) {
    $prefix = 'Default service location';
  }
  $prefix .= ($opt{join_string} ||  ': ') if $prefix;
  $prefix . $self->SUPER::location_label(%opt);
}

=back

=head1 CLASS METHODS

=item in_county_sql OPTIONS

Returns an SQL expression to test membership in a cust_main_county 
geographic area.  By default, this requires district, city, county,
state, and country to match exactly.  Pass "ornull => 1" to allow 
partial matches where some fields are NULL in the cust_main_county 
record but not in the location.

Pass "param => 1" to receive a parameterized expression (rather than
one that requires a join to cust_main_county) and a list of parameter
names in order.

=cut

sub in_county_sql {
  # replaces FS::cust_pkg::location_sql
  my ($class, %opt) = @_;
  my $ornull = $opt{ornull} ? ' OR ? IS NULL' : '';
  my $x = $ornull ? 3 : 2;
  my @fields = (('district') x 3,
                ('city') x 3,
                ('county') x $x,
                ('state') x $x,
                'country');

  my @where = (
    "cust_location.district = ? OR ? = '' OR CAST(? AS text) IS NULL",
    "cust_location.city     = ? OR ? = '' OR CAST(? AS text) IS NULL",
    "cust_location.county   = ? OR (? = '' AND cust_location.county IS NULL) $ornull",
    "cust_location.state    = ? OR (? = '' AND cust_location.state IS NULL ) $ornull",
    "cust_location.country = ?"
  );
  my $sql = join(' AND ', map "($_)\n", @where);
  if ( $opt{param} ) {
    return $sql, @fields;
  }
  else {
    # do the substitution here
    foreach (@fields) {
      $sql =~ s/\?/cust_main_county.$_/;
      $sql =~ s/cust_main_county.$_ = ''/cust_main_county.$_ IS NULL/;
    }
    return $sql;
  }
}

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_pkg>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

