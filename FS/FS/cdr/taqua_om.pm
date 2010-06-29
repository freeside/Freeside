package FS::cdr::taqua_om;

use strict;
use vars qw( %info );
use base qw( FS::cdr::taqua );

%info = (
  %FS::cdr::taqua::info,
  'name'         => 'Taqua OM',
  'weight'       => 132,
  'header'       => 0,
  'sep_char'     => ';',
  'row_callback' => sub { my $row = shift;
                          $row =~ s/^<\d+>\|[\da-f\|]+\|(\d+;)/$1/;
                          $row;
                        },
);

1;
