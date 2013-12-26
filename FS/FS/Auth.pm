package FS::Auth;

use strict;
use FS::Conf;

sub authenticate {
  my $class = shift;

  $class->auth_class->authenticate(@_);
}

sub auth_class {
  #my($class) = @_;

  my $conf = new FS::Conf;
  my $module = lc($conf->config('authentication_module')) || 'internal';

  my $auth_class = 'FS::Auth::'.$module;
  eval "use $auth_class;";
  die $@ if $@;

  $auth_class;
}

1;
