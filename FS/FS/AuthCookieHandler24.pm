package FS::AuthCookieHandler24;
use base qw( FS::AuthCookieHandler );

use strict;

#Apache 2.4+ / Apache2::AuthCookie 3.19+
sub useragent_ip {
  my( $self, $r ) = @_;
  $r->useragent_ip;
}

1;
