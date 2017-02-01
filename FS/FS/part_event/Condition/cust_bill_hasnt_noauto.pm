package FS::part_event::Condition::cust_bill_hasnt_noauto;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Invoice eligible for automatic collection';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  ! $cust_bill->no_auto;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  
  # can be made still faster with optimizations?

  "NOT EXISTS ( SELECT 1 FROM cust_pkg 
                           LEFT JOIN part_pkg USING (pkgpart)
                  WHERE ( cust_pkg.no_auto = 'Y' OR part_pkg.no_auto = 'Y' )
                    AND cust_pkg.pkgnum IN
                          ( SELECT DISTINCT cust_bill_pkg.pkgnum 
                              FROM cust_bill_pkg
                              WHERE cust_bill_pkg.invnum = cust_bill.invnum
                                AND cust_bill_pkg.pkgnum > 0
                          )
              )
  ";
}

1;
