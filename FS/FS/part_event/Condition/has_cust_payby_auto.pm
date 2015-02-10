package FS::part_event::Condition::has_cust_payby_auto;

use strict;
use Tie::IxHash;
use FS::payby;

use base qw( FS::part_event::Condition );

sub description {
  'Customer has automatic payment information';
}

tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2shortname;
delete $payby{'DCRD'};
delete $payby{'DCHK'};

sub option_fields {
  (
    'payby' => { 
                 label         => 'Has automatic payment info',
                 type          => 'select',
                 options       => [ keys %payby ],
                 option_labels => \%payby,
               },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  scalar( qsearch({ 
    'table'     => 'cust_payby',
    'hashref'   => { 'custnum' => $cust_main->custnum,
                     'payby'   => $self->option('payby')
                   },
    'order_by'  => 'LIMIT 1',
  }) );

}

1;
