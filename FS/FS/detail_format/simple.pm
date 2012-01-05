package FS::detail_format::simple;

use strict;
use base qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Simple' }

sub header_detail { 'Date,Time,Name,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    $cdr->userfield,
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
