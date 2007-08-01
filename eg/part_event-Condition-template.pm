package FS::part_event::Condition::mycondition;

use strict;

use base qw( FS::part_event::Condition );

# see the FS::part_event::Condition manpage for full documentation on each
# of the required and optional methods.

sub description {
  'New condition (the author forgot to change this description)';
}

#sub eventtable_hashref {
#    { 'cust_main'      => 1,
#      'cust_bill'      => 1,
#      'cust_pkg'       => 1,
#      'cust_pay_batch' => 1,
#    };
#}

#sub option_fields {
#  (
#    'field'         => 'description',
#
#    'another_field' => { 'label'=>'Amount', 'type'=>'money', },
#
#    'third_field'   => { 'label'         => 'Types',
#                         'type'          => 'checkbox-multiple',
#                         'options'       => [ 'h', 's' ],
#                         'option_labels' => { 'h' => 'Happy',
#                                              's' => 'Sad',
#                                            },
#  );
#}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $value_of_field = $self->option('field');

  my $time = $opt{'time'}; #use this instead of time or $^T

  #test your condition
  1;

}

#sub condition_sql {
#  my( $class, $table ) = @_;
#  #...
#  'true';
#}

1;
