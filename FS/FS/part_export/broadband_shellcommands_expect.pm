package FS::part_export::broadband_shellcommands_expect;
use base qw( FS::part_export::shellcommands_expect );

use strict;
use FS::part_export::broadband_shellcommands;

our %info = %FS::part_export::shellcommands_expect::info;
$info{'svc'}  = 'svc_broadband';
$info{'desc'} = 'Real time export via remote SSH, with interactive ("Expect"-like) scripting, for svc_broadband services';

sub _export_subvars {
  FS::part_export::broadband_shellcommands::_export_subvars(@_)
}

sub _export_subvars_replace {
  FS::part_export::broadband_shellcommands::_export_subvars_replace(@_)
}

1;
