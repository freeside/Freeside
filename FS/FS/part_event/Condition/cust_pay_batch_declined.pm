package FS::part_event::Condition::cust_pay_batch_declined;

use strict;

use base qw( FS::part_event::Condition );

sub description {
  'Batch payment declined';
}

sub eventtable_hashref {
    { 'cust_main'      => 0,
      'cust_bill'      => 0,
      'cust_pkg'       => 0,
      'cust_pay_batch' => 1,
    };
}

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
  my($self, $cust_pay_batch, %opt) = @_;

  #my $cust_main = $self->cust_main($object);
  #my $value_of_field = $self->option('field');
  #my $time = $opt{'time'}; #use this instead of time or $^T

  $cust_pay_batch->status =~ /Declined/i;

}

#sub condition_sql {
#  my( $class, $table ) = @_;
#  #...
#  'true';
#}

1;
