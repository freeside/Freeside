package FS::cdr::nextone;

use strict;
use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Nextone',
  'weight'        => 200,
  'header'        => 1,
  'import_fields' => [
    'userfield',  #CallZoneData ???userfield
    'channel',    #OrigGw
    'dstchannel', #TermGw
    'duration',   #Duration
    'dst',        #CallDTMF
    'src',        #Ani
    'startdate',  #DateTimeInt
  ],
);

1;
