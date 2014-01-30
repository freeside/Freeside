package FS::detail_format::description_default;

use strict;
use base qw(FS::detail_format);

sub name { 'Default with description field as destination' }

sub header_detail { 'Caller,Date,Time,Number,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $cdr->src,
    $self->time2str_local($self->date_format, $cdr->startdate),
    $self->time2str_local('%r', $cdr->startdate),
    ($cdr->rated_pretty_dst || $cdr->dst),
    $cdr->description,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
