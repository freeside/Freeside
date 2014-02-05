package FS::detail_format::basic_upstream_dst_regionname;

use strict;
use base qw(FS::detail_format);

sub name { 'Basic with upstream destination name' }

sub header_detail { 'Date/Time,Called Number,Destination,Min/Sec,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $self->time2str_local('%d %b - %I:%M %p', $cdr->startdate),
    $cdr->dst,
    $cdr->upstream_dst_regionname,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
