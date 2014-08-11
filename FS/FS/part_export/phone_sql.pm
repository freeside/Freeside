package FS::part_export::phone_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
#use Tie::IxHash;

#tie my %options, 'Tie::IxHash',
#  %{__PACKAGE__->sql_options},
#  #more options...
#;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Real time export of phone numbers (DIDs) to SQL databases',
  'options' => __PACKAGE__->sql_options, #\%options,
  'no_machine' => 1,
  'notes'      => <<END
Export phone numbers (DIDs) to SQL databases.
END
);

1;
