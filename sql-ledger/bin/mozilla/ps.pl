# point of sale script

use SL::AR;
use SL::IS;
use SL::RP;

require "$form->{path}/ar.pl";
require "$form->{path}/is.pl";
require "$form->{path}/rp.pl";
require "$form->{path}/pos.pl";

# customizations
if (-f "$form->{path}/custom_ar.pl") {
  eval { require "$form->{path}/custom_ar.pl"; };
}
if (-f "$form->{path}/$form->{login}_ar.pl") {
  eval { require "$form->{path}/$form->{login}_ar.pl"; };
}

if (-f "$form->{path}/custom_is.pl") {
  eval { require "$form->{path}/custom_is.pl"; };
}
if (-f "$form->{path}/$form->{login}_is.pl") {
  eval { require "$form->{path}/$form->{login}_is.pl"; };
}

if (-f "$form->{path}/custom_rp.pl") {
  eval { require "$form->{path}/custom_rp.pl"; };
}
if (-f "$form->{path}/$form->{login}_rp.pl") {
  eval { require "$form->{path}/$form->{login}_rp.pl"; };
}

if (-f "$form->{path}/custom_pos.pl") {
  eval { require "$form->{path}/custom_pos.pl"; };
}
if (-f "$form->{path}/$form->{login}_pos.pl") {
  eval { require "$form->{path}/$form->{login}_pos.pl"; };
}

1;
# end
