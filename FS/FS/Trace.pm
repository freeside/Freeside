package FS::Trace;

use strict;
use Date::Format;
use File::Slurp;

my @trace = ();

sub log {
  my( $class, $msg ) = @_;
  push @trace, [ time, "[$$][". time2str('%r', time). "] $msg" ];
}

sub total {
  $trace[-1]->[0] - $trace[0]->[0];
}

sub reset {
  @trace = ();
}

sub dump_ary {
  map $_->[1], @trace;
}

sub dump {
  join("\n", map $_->[1], @trace). "\n";
}

sub dumpfile {
  my( $class, $filename, $header ) = @_;
  write_file( $filename, "$header\n". $class->dump );
}

1;
