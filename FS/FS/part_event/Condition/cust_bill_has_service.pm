package FS::part_event::Condition::cust_bill_has_service;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Invoice is billing for (any of) certain service definitions';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

# could not find component for path '/elements/tr-select-part_svc.html'
# sub disabled { 1; }

sub option_fields {
  (
    'has_service' => { 'label'      => 'Has service',
                       'type'       => 'select-part_svc',
                       'multiple'   => 1, #the HTML element seems to have it
                                          #by default, but edit/part_event.html
                                          #(and process) need to know
                     },
  );
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  my $servicenum = $self->option('has_service') || {};

  grep $servicenum->{ $_->svcpart },
    map $_->cust_svc,
        $cust_bill->cust_pkg;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $servicenum =
    $class->condition_sql_option_option('has_service');

  my $sql = qq| 0 < ( SELECT COUNT(cs.svcpart)
     FROM cust_bill_pkg cbp, cust_svc cs
    WHERE cbp.invnum = cust_bill.invnum
      AND cs.pkgnum = cbp.pkgnum
      AND cs.svcpart IN $servicenum
  )
  |;
  return $sql;
}

1;
