package FS::detail_format::simple2;

use strict;
use parent qw(FS::detail_format);
use Date::Format qw(time2str);

sub name { 'Simple with source' }

sub header_detail { 'Date,Time,Name,Called From,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    time2str($self->date_format, $cdr->startdate),
    time2str('%r', $cdr->startdate),
    $cdr->userfield,
    $cdr->src,
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
