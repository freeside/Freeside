package FS::state;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use Locale::SubCountry;

=head1 NAME

FS::state - Object methods for state/province records

=head1 SYNOPSIS

  use FS::state;

  $record = new FS::state \%hash;
  $record = new FS::state { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::state object represents a state, province, or other top-level 
subdivision of a sovereign nation.  FS::state inherits from FS::Record.  
The following fields are currently supported:

=over 4

=item statenum

primary key

=item country

two-letter country code

=item state

state code/abbreviation/name (as used in cust_location.state)

=item fips

FIPS 10-4 code (not including country code)

=back

=head1 METHODS

=cut

sub table { 'state'; }

# no external API; this table maintains itself

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('statenum')
    || $self->ut_alpha('country')
    || $self->ut_alpha('state')
    || $self->ut_alpha('fips')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=cut

our %state2fips = (
  'AL' => '01',
  'AK' => '02',
  'AZ' => '04',
  'AR' => '05',
  'CA' => '06',
  'CO' => '08',
  'CT' => '09',
  'DE' => '10',
  'DC' => '11',
  'FL' => '12',
  'GA' => '13',
  'HI' => '15',
  'ID' => '16',
  'IL' => '17',
  'IN' => '18',
  'IA' => '19',
  'KS' => '20',
  'KY' => '21',
  'LA' => '22',
  'ME' => '23',
  'MD' => '24',
  'MA' => '25',
  'MI' => '26',
  'MN' => '27',
  'MS' => '28',
  'MO' => '29',
  'MT' => '30',
  'NE' => '31',
  'NV' => '32',
  'NH' => '33',
  'NJ' => '34',
  'NM' => '35',
  'NY' => '36',
  'NC' => '37',
  'ND' => '38',
  'OH' => '39',
  'OK' => '40',
  'OR' => '41',
  'PA' => '42',
  'RI' => '44',
  'SC' => '45',
  'SD' => '46',
  'TN' => '47',
  'TX' => '48',
  'UT' => '49',
  'VT' => '50',
  'VA' => '51',
  'WA' => '53',
  'WV' => '54',
  'WI' => '55',
  'WY' => '56',

  'AS' => '60', #American Samoa
  'GU' => '66', #Guam
  'MP' => '69', #Northern Mariana Islands
  'PR' => '72', #Puerto Rico
  'VI' => '78', #Virgin Islands
);

sub _upgrade_data {
  # we only need U.S. state codes at this point (for FCC 477 reporting)
  warn "Updating state FIPS codes...\n";
  my %existing;
  foreach my $state ( qsearch('state', {'country'=>'US'}) ) {
    $existing{$state->country} ||= {};
    $existing{$state->country}{$state->state} = $state;
  }
  foreach my $country_code ('US') {
    my $country = Locale::SubCountry->new($country_code);
    next unless $country->has_sub_countries;
    $existing{$country} ||= {};
    foreach my $state_code ($country->all_codes) {
      my $fips = $state2fips{$state_code} || next;
      my $this_state = $existing{$country_code}{$state_code};
      if ($this_state) {
        if ($this_state->fips ne $fips) { # this should never happen...
          die "guru meditation #414: State FIPS codes shouldn't change";
          #$this_state->set(fips => $fips);
          #my $error = $this_state->replace;
          #die "error updating $country_code/$state_code:\n$error\n" if $error;
        }
        delete $existing{$country_code}{$state_code};
      } else {
        $this_state = FS::state->new({
          country => $country_code,
          state   => $state_code,
          fips    => $fips,
        });
        my $error = $this_state->insert;
        die "error inserting $country_code/$state_code:\n$error\n" if $error;
      }
    }
    # clean up states that no longer exist (does this ever happen?)
    foreach my $state (values %{ $existing{$country_code} }) {
      die "guru meditation #415: State that no longer exists?";
      #my $error = $state->delete;
      #die "error removing expired state ".$state->country.'/'.$state->state.
      #    "\n$error\n" if $error;
    }
  } # foreach $country_code
  '';
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

