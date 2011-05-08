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
  
  # XXX: can be made faster with optimizations?
  # -remove some/all sub-selects?
  # -remove the two main separate selects?
  # -add indices on cust_pkg.no_auto and part_pkg.no_auto and others?

  "0 = (select count(1) from cust_pkg 
            where cust_pkg.no_auto = 'Y' and cust_pkg.pkgnum in
                (select distinct cust_bill_pkg.pkgnum 
                    from cust_bill_pkg, cust_pkg 
                    where cust_bill_pkg.pkgnum = cust_pkg.pkgnum
                        and cust_bill_pkg.invnum = cust_bill.invnum
                        and cust_bill_pkg.pkgnum > 0
                )
        )
   AND
   0 = (select count(1) from part_pkg 
            where part_pkg.no_auto = 'Y' and part_pkg.pkgpart in
                (select cust_pkg.pkgpart from cust_pkg 
                    where pkgnum in 
                        (select distinct cust_bill_pkg.pkgnum 
                            from cust_bill_pkg, cust_pkg 
                            where cust_bill_pkg.pkgnum = cust_pkg.pkgnum 
                                and cust_bill_pkg.invnum = cust_bill.invnum
                                and cust_bill_pkg.pkgnum > 0
                        ) 
                )
        )
  ";
}

1;
