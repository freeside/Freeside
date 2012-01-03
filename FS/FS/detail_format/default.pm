package FS::detail_format::default;

use strict;
use parent qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Default' }

sub header_detail { 'Date,Time,Number,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    ($cdr->rated_pretty_dst || $cdr->dst),
    $cdr->rated_regionname,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
