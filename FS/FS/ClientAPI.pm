package FS::ClientAPI;

use strict;
use vars qw(%handler $domain $DEBUG);

$DEBUG = 0;

%handler = ();

#find modules
foreach my $INC ( @INC ) {
  my $glob = "$INC/FS/ClientAPI/*.pm";
  warn "FS::ClientAPI: searching $glob" if $DEBUG;
  foreach my $file ( glob($glob) ) {
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized ClientAPI file: $file";
      next
    };
    my $mod = $1;
    warn "using FS::ClientAPI::$mod" if $DEBUG;
    eval "use FS::ClientAPI::$mod;";
    die "error using FS::ClientAPI::$mod: $@" if $@;
  }
}

#---

sub dispatch {
  my ( $self, $name ) = ( shift, shift );
  $name =~ s(/)(::)g;
  my $sub = "FS::ClientAPI::$name";
  no strict 'refs';
  &{$sub}(@_);
}

1;

