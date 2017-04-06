package FS::part_export::cable_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
#use Tie::IxHash;

#tie my %options, 'Tie::IxHash',
#  %{__PACKAGE__->sql_options},
#  #more options...
#;

%info = (
  'svc'     => 'svc_cable',
  'desc'    => 'Real time export of cable service to SQL databases',
  'options' => __PACKAGE__->sql_options, #\%options,
  'no_machine' => 1,
  'notes'      => <<END
Export cable service to SQL databases.
END
);

1;
