package FS::part_event::Condition::dundate;

use strict;

use base qw( FS::part_event::Condition );

sub description {
  "Skip until customer dun date is reached";
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  $cust_main->dundate <= $opt{time};

}

#sub condition_sql {
#  my( $self, $table ) = @_;
#
#  'true';
#}

1;
