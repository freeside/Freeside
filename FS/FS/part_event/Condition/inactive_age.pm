package FS::part_event::Condition::inactive_age;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description { 'Days without billing activity' }

sub option_fields {
  (
    'age'  =>  { 'label'   => 'No activity within',
                 'type'    => 'freq',
               },
    'ignore_pkgclass' =>
               { 'label' => 'Except charges of class',
                 'type'  => 'select-pkg_class',
               },
    # flags to select kinds of activity, 
    # like if you just want "no payments since"?
    # not relevant yet
  );
}

sub condition {
  my( $self, $obj, %opt ) = @_;
  my $custnum = $obj->custnum;
  my $age = $self->option_age_from('age', $opt{'time'} );

  my $ignore_pkgclass = $self->option('ignore_pkgclass');

  my $where = "custnum = $custnum AND _date >= $age";

  foreach my $t (qw(cust_pay cust_credit cust_refund)) {
    my $class = "FS::$t";
    return 0 if $class->count($where);
  }

  # cust_bill: handle the ignore_pkgclass option
  if ( $ignore_pkgclass =~ /^\d+$/ ) {
    $where .= " AND EXISTS( ".
      "SELECT 1 FROM cust_bill_pkg JOIN cust_pkg USING (pkgnum) " .
      "JOIN part_pkg USING (pkgpart) " .
      "WHERE cust_bill_pkg.invnum = cust_bill.invnum " .
      "AND COALESCE(part_pkg.classnum, -1) != $ignore_pkgclass" .
      " )";
  }
  #warn "$where\n";
  return 0 if FS::cust_bill->count($where);

  1;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $age   = $class->condition_sql_option_age_from('age', $opt{'time'});
  my $ignore_pkgclass = $class->condition_sql_option_integer('ignore_pkgclass');
  # will evaluate to zero if there isn't one
  my @sql;
  for my $t (qw(cust_pay cust_credit cust_refund)) {
    push @sql, "
      NOT EXISTS( SELECT 1 FROM $t
                    WHERE $t.custnum = cust_main.custnum AND $t._date >= $age
                    LIMIT 1
                )
    ";
  }
  #cust_bill
  push @sql, "
    NOT EXISTS(
                SELECT 1 FROM cust_bill JOIN cust_bill_pkg USING (invnum)
                      JOIN cust_pkg USING (pkgnum) JOIN part_pkg USING (pkgpart)
                  WHERE cust_bill.custnum = cust_main.custnum
                    AND cust_bill._date >= $age
                    AND COALESCE(part_pkg.classnum, -1) != $ignore_pkgclass
                  LIMIT 1
              )
  ";
  join(' AND ', @sql);
}

1;

