package FS::ClientAPI;

use strict;
use vars qw(%handler $domain);

%handler = ();

#find modules
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/ClientAPI/*.pm") ) {
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized ClientAPI file: $file";
      next
    };
    my $mod = $1;
    #warn "using FS::ClientAPI::$mod";
    eval "use FS::ClientAPI::$mod;";
    die "error using FS::ClientAPI::$mod: $@" if $@;
  }
}

#(sub for modules)
sub register_handlers {
  my $self = shift;
  my %new_handlers = @_;
  foreach my $key ( keys %new_handlers ) {
    warn "WARNING: redefining sub $key" if exists $handler{$key};
    #warn "registering $key";
    $handler{$key} = $new_handlers{$key};
  }
}

#---

sub dispatch {
  my ( $self, $name ) = ( shift, shift );
  my $sub = $handler{$name}
    or die "unknown FS::ClientAPI sub $name (known: ". join(" ", keys %handler );
    #or die "unknown FS::ClientAPI sub $name";
  &{$sub}(@_);
}

1;

