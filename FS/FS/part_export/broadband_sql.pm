package FS::part_export::broadband_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
use Tie::IxHash;

tie my %options, 'Tie::IxHash',
  %{__PACKAGE__->sql_options},
  # likely to be necessary
  'mac_case' => {
    label   => 'Export MAC address as',
    type    => 'select',
    options => [ qw(uppercase lowercase) ],
  },
  mac_delimiter => {
    label   => 'Separate MAC address octets with',
    default => '-',
  },
;

%info = (
  'svc'      => 'svc_broadband',
  'desc'     => 'Real-time export of broadband services to SQL databases ',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
END
);

# to avoid confusion, let the user just enter "mac_addr" as the column name
sub _schema_map {
  my %map = shift->_map('schema');
  for (values %map) {
    s/^mac_addr$/mac_addr_formatted/;
  }
  %map;
}

sub _map_arg_callback {
  my($self, $field) = @_;
  if ( $field eq 'mac_addr_formatted' ) {
    return ($self->option('mac_case'), $self->option('mac_delimiter'));
  }
  return ();
}

1;

