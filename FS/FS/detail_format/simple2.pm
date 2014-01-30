package FS::detail_format::simple2;

use strict;
use base qw(FS::detail_format);

sub name { 'Simple with source' }

sub header_detail { 'Date,Time,Name,Called From,Destination,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $self->time2str_local($self->date_format, $cdr->startdate),
    $self->time2str_local('%r', $cdr->startdate),
    $cdr->userfield,
    $cdr->src,
    $cdr->dst,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
