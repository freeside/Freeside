package FS::svc_CGP_Mixin;

use strict;

=head1 NAME

FS::svc_CGP_Mixin - Mixin class for svc_classes which can be related to cgp_rule

=head1 SYNOPSIS

package FS::svc_table;
use base qw( FS::svc_CGP_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that are exported to Communigate Pro.

It currently contains timezone data for domains and accounts.

=head1 METHODS

=over 4

=item cgp_timezone

Returns an arrayref of Communigate time zones.

=cut

#http://www.communigate.com/pub/client/TimeZones.data 
#http://www.communigate.com/cgatepro/WebMail.html#Settings 

sub cgp_timezone {
  #my $self = shift; #i'm used as a class and object method but just return data

  [ '',
    'HostOS',
    '(+0100) Algeria/Congo',
    '(+0200) Egypt/South Africa',
    '(+0300) Saudi Arabia',
    '(+0400) Oman',
    '(+0500) Pakistan',
    '(+0600) Bangladesh',
    '(+0700) Thailand/Vietnam',
    '(+0800) China/Malaysia',
    '(+0900) Japan/Korea',
    '(+1000) Queensland',
    '(+1100) Micronesia',
    '(+1200) Fiji',
    '(+1300) Tonga/Kiribati',
    '(+1400) Christmas Islands',
    '(-0100) Azores/Cape Verde',
    '(-0200) Fernando de Noronha',
    '(-0300) Argentina/Uruguay',
    '(-0400) Venezuela/Guyana',
    '(-0500) Haiti/Peru',
    '(-0600) Central America',
    '(-0700) Arisona', #Arizona?
    '(-0800) Adamstown',
    '(-0900) Marquesas Islands',
    '(-1000) Hawaii/Tahiti',
    '(-1100) Samoa',
    'Asia/Afghanistan',
    'Asia/India',
    'Asia/Iran',
    'Asia/Iraq',
    'Asia/Israel',
    'Asia/Jordan',
    'Asia/Lebanon',
    'Asia/Syria',
    'Australia/Adelaide',
    'Australia/East',
    'Australia/NorthernTerritory',
    'Europe/Central',
    'Europe/Eastern',
    'Europe/Moscow',
    'Europe/Western',
    'GMT (+0000)',
    'Newfoundland',
    'NewZealand/Auckland',
    'NorthAmerica/Alaska',
    'NorthAmerica/Atlantic',
    'NorthAmerica/Central',
    'NorthAmerica/Eastern',
    'NorthAmerica/Mountain',
    'NorthAmerica/Pacific',
    'Russia/Ekaterinburg',
    'Russia/Irkutsk',
    'Russia/Kamchatka',
    'Russia/Krasnoyarsk',
    'Russia/Magadan',
    'Russia/Novosibirsk',
    'Russia/Vladivostok',
    'Russia/Yakutsk',
    'SouthAmerica/Brasil',
    'SouthAmerica/Chile',
    'SouthAmerica/Paraguay',
  ];

}

=back

=head1 BUGS

=head1 SEE ALSO

=cut

1;
