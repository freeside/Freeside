package FS::detail_format::accountcode_simple;

use strict;
use base qw(FS::detail_format);

sub name { 'Simple with source' }

sub header_detail { 'Date,Time,Called From,Account,Duration,Price' }

sub columns {
  my $self = shift;
  my $cdr = shift;
  (
    $self->time2str_local($self->date_format, $cdr->startdate),
    $self->time2str_local('%r', $cdr->startdate),
    $cdr->src,
    $cdr->accountcode,
    $self->duration($cdr),
    $self->price($cdr),
  )
}

1;
