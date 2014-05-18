package FS::Locales;

use strict;
use Tie::IxHash;

=head1 NAME

FS::Locales - Supported locales

=head1 SYNOPSIS

  use FS::Locales;

  my @locales = FS::Locales->locales;

=head1 DESCRIPTION

FS::Locales provides a list of supported locales.

=head1 CLASS METHODS

=over 4

=item locales

Returns a list of the available locales.

=cut

tie our %locales, 'Tie::IxHash',
  'en_US', { name => 'English',        country => 'United States', },
  'en_AU', { name => 'English',        country => 'Australia', },
  'en_CA', { name => 'English',        country => 'Canada', },
  'fr_CA', { name => 'French',         country => 'Canada', },
  'fr_FR', { name => 'French',         country => 'France', },
  'fr_HT', { name => 'French',         country => 'Haiti', },
  'ht_HT', { name => 'Haitian Creole', country => 'Haiti', },
  'iw_IL', { name => 'Hebrew',         country => 'Israel', rtl=>1, },
;

$_->{label} = $_->{name} . ' (' . $_->{country} . ')'
  foreach values %locales;

sub locales {
  keys %locales;
}

=item locale_info LOCALE

Returns a hash of information about a locale.

=cut

sub locale_info {
  my($class, $locale) = @_;
  if (!$locale) {
    return ();
  } elsif (exists $locales{$locale}) {
    return %{ $locales{$locale} };
  } else {
    die "unsupported locale '$locale'\n";
  }
}

=item description LOCALE

Returns "Language (Country)" for a locale.

=cut

sub description {
  my($class, $locale) = @_;
  $locales{$locale}->{'name'} . ' (' . $locales{$locale}->{'country'} . ')';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Msgcat>

=cut

1;

