package FS::detail_format::source_default;

use strict;
use parent qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Default with source' }

sub header_detail { 'Caller,Date,Time,Number,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $cdr->src,
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    ($cdr->rated_pretty_dst || $cdr->dst),
    $cdr->rated_regionname,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
