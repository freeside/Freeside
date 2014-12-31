package FS::part_event::Condition::cust_bill_age_before_payby;
use base qw( FS::part_event::Condition );

use strict;
use FS::Record qw( qsearchs );
use FS::h_cust_main;

sub description { 'Invoice is newer than last payment type change'; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub condition {
  my( $self, $cust_bill, %opt ) = @_;

  #my $cust_main = $cust_bill->cust_main;

  my $change_date = 0;
  my $newest = 2147483647; #2038 problem, because the field does

  #this is pretty expensive, it would be way more efficient to check for
  # changed payby in SQL
  #  (it would also help if a replace_new had a real FK ref to its replace_old)
  while ( my $replace_new = qsearchs({
            'table' => 'h_cust_main',
            'hashref'  => { 'custnum'        => $cust_bill->custnum,
                            'history_action' => 'replace_new',
                            'history_date'   => { op=>'<', value=>$newest },
                          },
            'order_by' => 'ORDER BY history_date DESC LIMIT 1',
        }))
  {
    my $newest = $replace_new->history_date;
    my $replace_old = qsearchs({
      'table' => 'h_cust_main',
      'hashref' => { 'custnum'        => $replace_new->custnum,
                     'history_action' => 'replace_old',
                     'history_date'   => $replace_new->history_date,
                   }
    }) or next; #no replace_old?  ignore and continue on i guess

    if ( $replace_new->payby ne $replace_old->payby ) {
      $change_date = $replace_new->history_date;
      last;
    }

  }

  ( $cust_bill->_date ) > $change_date;

}

1;
