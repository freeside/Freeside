package FS::part_event::Condition::cust_pay_payby;

use strict;
use base qw( FS::part_event::Condition );
use FS::payby;
use FS::Record qw( qsearchs );
use FS::cust_pay;

sub description { 'Type of most recent payment'; }

tie my %payby, 'Tie::IxHash', FS::payby->payment_payby2payname;

sub option_fields {
  (
    'payby' => {
                 label         => 'Payment type',
                 type          => 'checkbox-multiple',
                 options       => [ keys %payby ],
                 option_labels => \%payby,
               },
  );
}

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $cust_pay = qsearchs({ 'table'    => 'cust_pay',
                            'hashref'  => { 'custnum'=>$cust_main->custnum },
                            'order_by' => 'ORDER BY _date DESC LIMIT 1',
                         })
    or return 0;

  my $payby = $self->option('payby') || {};
  $payby->{ $cust_pay->payby };

}

1;
