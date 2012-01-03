package FS::detail_format::basic;

use strict;
use parent qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Basic' }

sub header_detail { 'Date/Time,Called Number,Min/Sec,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    time2str('%d %b - %I:%M %p', $cdr->startdate),
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
