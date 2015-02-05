package FS::part_event::Condition::nopostal;
use base qw( FS::part_event::Condition );
use strict;

sub description {
  'Customer does not receive a postal mail invoice';
}

sub condition {
  my( $self, $object ) = @_;
  my $cust_main = $self->cust_main($object);

  scalar( grep { $_ eq 'POST' } $cust_main->invoicing_list ) ? 0 : 1;
}

sub condition_sql {
  my( $self, $table ) = @_;

  " NOT EXISTS( SELECT 1 FROM cust_main_invoice
              WHERE cust_main_invoice.custnum = cust_main.custnum
                AND cust_main_invoice.dest    = 'POST'
          )
  ";
}

1;
