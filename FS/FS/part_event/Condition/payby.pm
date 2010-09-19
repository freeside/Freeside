package FS::part_event::Condition::payby;

use strict;
use Tie::IxHash;
use FS::payby;

use base qw( FS::part_event::Condition );

sub description {
  #'customer payment types: ';
  'Customer payment type';
}

#something like this
tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname;
sub option_fields {
  (
    'payby' => { 
                 label         => 'Customer payment type',
                 #type          => 'select-multiple',
                 type          => 'checkbox-multiple',
                 options       => [ keys %payby ],
                 option_labels => \%payby,
               },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $hashref = $self->option('payby') || {};
  $hashref->{ $cust_main->payby };

}

sub condition_sql {
  my( $self, $table ) = @_;

  'cust_main.payby IN '. $self->condition_sql_option_option('payby');
}

1;
