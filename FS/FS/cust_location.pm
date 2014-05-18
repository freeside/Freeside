package FS::cust_location;
use base qw( FS::geocode_Mixin FS::Record );

use strict;
use vars qw( $import $DEBUG $conf $label_prefix );
use Data::Dumper;
use Date::Format qw( time2str );
use Locale::Country;
use FS::UID qw( dbh driver_name );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::prospect_main;
use FS::cust_main;
use FS::cust_main_county;
use FS::part_export;
use FS::GeocodeCache;

$import = 0;

$DEBUG = 0;

FS::UID->install_callback( sub {
  $conf = FS::Conf->new;
  $label_prefix = $conf->config('cust_location-label_prefix') || '';
});

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

=item find_or_insert

Finds an existing location matching the customer and address values in this
location, if one exists, and sets the contents of this location equal to that
one (including its locationnum).

If an existing location is not found, this one I<will> be inserted.  (This is a
change from the "new_or_existing" method that this replaces.)

The following fields are considered "essential" and I<must> match: custnum,
address1, address2, city, county, state, zip, country, location_number,
location_type, location_kind.  Disabled locations will be found only if this
location is set to disabled.

All other fields are considered "non-essential" and will be ignored in 
finding a matching location.  If the existing location doesn't match 
in these fields, it will be updated in-place to match.

Returns an error string if inserting or updating a location failed.

It is unfortunately hard to determine if this created a new location or not.

=cut

sub find_or_insert {
  my $self = shift;

  warn "find_or_insert:\n".Dumper($self) if $DEBUG;

  my @essential = (qw(custnum address1 address2 city county state zip country
    location_number location_type location_kind disabled));

  # I don't think this is necessary
  #if ( !$self->coord_auto and $self->latitude and $self->longitude ) {
  #  push @essential, qw(latitude longitude);
  #  # but NOT coord_auto; if the latitude and longitude match the geocoded
  #  # values then that's good enough
  #}

  # put nonempty, nonessential fields/values into this hash
  my %nonempty = map { $_ => $self->get($_) }
                 grep {$self->get($_)} $self->fields;
  delete @nonempty{@essential};
  delete $nonempty{'locationnum'};

  my %hash = map { $_ => $self->get($_) } @essential;
  my @matches = qsearch('cust_location', \%hash);

  # we no longer reject matches for having different values in nonessential
  # fields; we just alter the record to match
  if ( @matches ) {
    my $old = $matches[0];
    warn "found existing location #".$old->locationnum."\n" if $DEBUG;
    foreach my $field (keys %nonempty) {
      if ($old->get($field) ne $nonempty{$field}) {
        warn "altering $field to match requested location" if $DEBUG;
        $old->set($field, $nonempty{$field});
      }
    } # foreach $field

    if ( $old->modified ) {
      warn "updating non-essential fields\n" if $DEBUG;
      my $error = $old->replace;
      return $error if $error;
    }
    # set $self equal to $old
    foreach ($self->fields) {
      $self->set($_, $old->get($_));
    }
    return "";
  }

  # didn't find a match
  warn "not found; inserting new location\n" if $DEBUG;
  return $self->insert;
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  if ( $self->censustract ) {
    $self->set('censusyear' => $conf->config('census_year') || 2012);
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  #false laziness with cust_main, will go away eventually
  if ( !$import and $conf->config('tax_district_method') ) {

    my $queue = new FS::queue {
      'job' => 'FS::geocode_Mixin::process_district_update'
    };
    $error = $queue->insert( ref($self), $self->locationnum );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  # cust_location exports
  #my $export_args = $options{'export_args'} || [];

  my @part_export =
    map qsearch( 'part_export', {exportnum=>$_} ),
      $conf->config('cust_location-exports'); #, $agentnum

  foreach my $part_export ( @part_export ) {
    my $error = $part_export->export_insert($self); #, @$export_args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "exporting to ". $part_export->exporttype.
             " (transaction rolled back): $error";
    }
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  # cust_location exports
  #my $export_args = $options{'export_args'} || [];

  my @part_export =
    map qsearch( 'part_export', {exportnum=>$_} ),
      $conf->config('cust_location-exports'); #, $agentnum

  foreach my $part_export ( @part_export ) {
    my $error = $part_export->export_replace($self, $old); #, @$export_args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "exporting to ". $part_export->exporttype.
             " (transaction rolled back): $error";
    }
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item check

Checks all fields to make sure this is a valid location.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  return '' if $self->disabled; # so that disabling locations never fails

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
    || $self->ut_enum('addr_clean', [ '', 'Y' ])
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

  # set coordinates, unless we already have them
  if (!$import and !$self->latitude and !$self->longitude) {
    $self->set_coord;
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
  $self->location_label(@_);
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
  return '' if FS::cust_main->count('bill_locationnum = '.$locationnum.' OR
                                     ship_locationnum = '.$locationnum)
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
  
  warn "move_to:\nFROM:".Dumper($old)."\nTO:".Dumper($new) if $DEBUG;

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

  # prevent this from failing because of pkg_svc quantity limits
  local( $FS::cust_svc::ignore_quantity ) = 1;

  if ( !$new->locationnum ) {
    $error = $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error creating location: $error";
    }
  } elsif ( $new->locationnum == $old->locationnum ) {
    # then they're the same location; the normal result of doing a minor
    # location edit
    $dbh->commit if $oldAutoCommit;
    return '';
  }

  # find all packages that have the old location as their service address,
  # and aren't canceled,
  # and aren't supplemental to another package.
  my @pkgs = qsearch('cust_pkg', { 
      'locationnum' => $old->locationnum,
      'cancel'      => '',
      'main_pkgnum' => '',
    });
  foreach my $cust_pkg (@pkgs) {
    # don't move one-time charges that have already been charged
    next if $cust_pkg->part_pkg->freq eq '0'
            and ($cust_pkg->setup || 0) > 0;

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
  my( $self, %opt ) = @_;

  my $cust_or_prospect = $opt{cust_main} || $opt{prospect_main};
  unless ( $cust_or_prospect ) {
    if ( $self->custnum ) {
      $cust_or_prospect = FS::cust_main->by_key($self->custnum);
    } elsif ( $self->prospectnum ) {
      $cust_or_prospect = FS::prospect_main->by_key($self->prospectnum);
    }
  }

  my $prefix = '';
  if ( $label_prefix eq 'CoStAg' ) {
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
  elsif (    ( $opt{'cust_main'} || $self->custnum )
          && $self->locationnum == $cust_or_prospect->ship_locationnum ) {
    $prefix = 'Default service location';
  }

  $prefix .= ($opt{join_string} ||  ': ') if $prefix;
  $prefix . $self->SUPER::location_label(%opt);
}

=item county_state_county

Returns a string consisting of just the county, state and country.

=cut

sub county_state_country {
  my $self = shift;
  my $label = $self->country;
  $label = $self->state.", $label" if $self->state;
  $label = $self->county." County, $label" if $self->county;
  $label;
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

  my $text = (driver_name =~ /^mysql/i) ? 'char' : 'text';

  my @where = (
    "cust_location.district = ? OR ? = '' OR CAST(? AS $text) IS NULL",
    "cust_location.city     = ? OR ? = '' OR CAST(? AS $text) IS NULL",
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

=back

=head2 SUBROUTINES

=over 4

=item process_censustract_update LOCATIONNUM

Queueable function to update the census tract to the current year (as set in 
the 'census_year' configuration variable) and retrieve the new tract code.

=cut

sub process_censustract_update {
  eval "use FS::GeocodeCache";
  die $@ if $@;
  my $locationnum = shift;
  my $cust_location = 
    qsearchs( 'cust_location', { locationnum => $locationnum })
      or die "locationnum '$locationnum' not found!\n";

  my $new_year = $conf->config('census_year') or return;
  my $loc = FS::GeocodeCache->new( $cust_location->location_hash );
  $loc->set_censustract;
  my $error = $loc->get('censustract_error');
  die $error if $error;
  $cust_location->set('censustract', $loc->get('censustract'));
  $cust_location->set('censusyear',  $new_year);
  $error = $cust_location->replace;
  die $error if $error;
  return;
}

=item process_set_coord

Queueable function to find and fill in coordinates for all locations that 
lack them.  Because this uses the Google Maps API, it's internally rate
limited and must run in a single process.

=cut

sub process_set_coord {
  my $job = shift;
  # avoid starting multiple instances of this job
  my @others = qsearch('queue', {
      'status'  => 'locked',
      'job'     => $job->job,
      'jobnum'  => {op=>'!=', value=>$job->jobnum},
  });
  return if @others;

  $job->update_statustext('finding locations to update');
  my @missing_coords = qsearch('cust_location', {
      'disabled'  => '',
      'latitude'  => '',
      'longitude' => '',
  });
  my $i = 0;
  my $n = scalar @missing_coords;
  for my $cust_location (@missing_coords) {
    $cust_location->set_coord;
    my $error = $cust_location->replace;
    if ( $error ) {
      warn "error geocoding location#".$cust_location->locationnum.": $error\n";
    } else {
      $i++;
      $job->update_statustext("updated $i / $n locations");
      dbh->commit; # so that we don't have to wait for the whole thing to finish
      # Rate-limit to stay under the Google Maps usage limit (2500/day).
      # 86,400 / 35 = 2,468 lookups per day.
    }
    sleep 35;
  }
  if ( $i < $n ) {
    die "failed to update ".$n-$i." locations\n";
  }
  return;
}

=item process_standardize [ LOCATIONNUMS ]

Performs address standardization on locations with unclean addresses,
using whatever method you have configured.  If the standardize_* method 
returns a I<clean> address match, the location will be updated.  This is 
always an in-place update (because the physical location is the same, 
and is just being referred to by a more accurate name).

Disabled locations will be skipped, as nobody cares.

If any LOCATIONNUMS are provided, only those locations will be updated.

=cut

sub process_standardize {
  my $job = shift;
  my @others = qsearch('queue', {
      'status'  => 'locked',
      'job'     => $job->job,
      'jobnum'  => {op=>'!=', value=>$job->jobnum},
  });
  return if @others;
  my @locationnums = grep /^\d+$/, @_;
  my $where = "AND locationnum IN(".join(',',@locationnums).")"
    if scalar(@locationnums);
  my @locations = qsearch({
      table     => 'cust_location',
      hashref   => { addr_clean => '', disabled => '' },
      extra_sql => $where,
  });
  my $n_todo = scalar(@locations);
  my $n_done = 0;

  # special: log this
  my $log;
  eval "use Text::CSV";
  open $log, '>', "$FS::UID::cache_dir/process_standardize-" . 
                  time2str('%Y%m%d',time) .
                  ".csv";
  my $csv = Text::CSV->new({binary => 1, eol => "\n"});

  foreach my $cust_location (@locations) {
    $job->update_statustext( int(100 * $n_done/$n_todo) . ",$n_done / $n_todo locations" ) if $job;
    my $result = FS::GeocodeCache->standardize($cust_location);
    if ( $result->{addr_clean} and !$result->{error} ) {
      my @cols = ($cust_location->locationnum);
      foreach (keys %$result) {
        push @cols, $cust_location->get($_), $result->{$_};
        $cust_location->set($_, $result->{$_});
      }
      # bypass immutable field restrictions
      my $error = $cust_location->FS::Record::replace;
      warn "location ".$cust_location->locationnum.": $error\n" if $error;
      $csv->print($log, \@cols);
    }
    $n_done++;
    dbh->commit; # so that we can resume if interrupted
  }
  close $log;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_pkg>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

