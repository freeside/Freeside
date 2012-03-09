package FS::detail_format::accountcode_simple;

use strict;
use base qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Simple with source' }

sub header_detail { 'Date,Time,Called From,Account,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    $cdr->src,
    $cdr->accountcode,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
