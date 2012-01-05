package FS::detail_format::description_default;

use strict;
use base qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Default with description field as destination' }

sub header_detail { 'Caller,Date,Time,Number,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $cdr->src,
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    ($cdr->rated_pretty_dst || $cdr->dst),
    $cdr->description,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
