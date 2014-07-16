package FS::UI::REST;
use base qw( Exporter );

use strict;
use vars qw( @EXPORT_OK );
use JSON::XS;
use FS::UID qw( adminsuidsetup );
use FS::Conf;

@EXPORT_OK = qw( rest_auth rest_uri_remain encode_rest );

sub rest_auth {
  my $cgi = shift;
  adminsuidsetup('fs_api');
  my $conf = new FS::Conf;
  die 'Incorrect shared secret'
    unless $cgi->param('secret') eq $conf->config('api_shared_secret');
}

sub rest_uri_remain {
  my($r, $m) = @_;

  #wacky way to get this... surely there must be a better way

  my $path = $m->request_comp->path;

  $r->uri =~ /\Q$path\E\/?(.*)$/ or die "$path not in ". $r->uri;

  $1;

}

sub encode_rest {
  #XXX HTTP Accept header to send other formats besides JSON
  encode_json(shift);
}

1;
