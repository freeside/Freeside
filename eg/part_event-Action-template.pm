package FS::part_event::Action::myaction;

use strict;

use base qw( FS::part_event::Action );

# see the FS::part_event::Action manpage for full documentation on each
# of the required and optional methods.

sub description {
  'New action (the author forgot to change this description)';
}

#sub eventtable_hashref {
#    { 'cust_main' => 1,
#      'cust_bill' => 1,
#      'cust_pkg'  => 1,
#    };
#}

#sub option_fields {
#  (
#    'field'         => 'description',
#
#    'another_field' => { 'label'=>'Amount', 'type'=>'money', },
#
#    'third_field'   => { 'label'         => 'Types',
#                         'type'          => 'select',
#                         'options'       => [ 'h', 's' ],
#                         'option_labels' => { 'h' => 'Happy',
#                                              's' => 'Sad',
#                                            },
#  );
#}

#sub default_weight {
#  100;
#}


sub do_action {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $value_of_field = $self->option('field');

  #do your action
  
  #die "Error: $error";
  return 'Null example action completed successfully.';

}

1;
