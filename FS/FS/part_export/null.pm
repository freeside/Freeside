package FS::part_export::null;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {}
sub _export_replace {}
sub _export_delete {}

1;
