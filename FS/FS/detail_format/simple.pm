package FS::detail_format::simple;

use strict;
use base qw(FS::detail_format);

sub name { 'Simple' }

sub header_detail { 'Date,Time,Name,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $self->time2str_local($self->date_format, $cdr->startdate),
    $self->time2str_local('%r', $cdr->startdate),
    $cdr->userfield,
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
