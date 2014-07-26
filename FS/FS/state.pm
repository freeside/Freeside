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

sub _upgrade_data {
  warn "Updating state and country codes...\n";
  my %existing;
  foreach my $state (qsearch('state')) {
    $existing{$state->country} ||= {};
    $existing{$state->country}{$state->state} = $state;
  }
  my $world = Locale::SubCountry::World->new;
  foreach my $country_code ($world->all_codes) {
    my $country = Locale::SubCountry->new($country_code);
    next unless $country->has_sub_countries;
    $existing{$country} ||= {};
    foreach my $state_code ($country->all_codes) {
      my $fips = $country->FIPS10_4_code($state_code);
      # we really only need U.S. state codes at this point, so if there's
      # no FIPS code, ignore it.
      next if !$fips or $fips eq 'unknown' or $fips =~ /\W/;
      my $this_state = $existing{$country_code}{$state_code};
      if ($this_state) {
        if ($this_state->fips ne $fips) { # this should never happen...
          $this_state->set(fips => $fips);
          my $error = $this_state->replace;
          die "error updating $country_code/$state_code:\n$error\n" if $error;
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
      my $error = $state->delete;
      die "error removing expired state ".$state->country.'/'.$state->state.
          "\n$error\n" if $error;
    }
  } # foreach $country_code
  '';
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

