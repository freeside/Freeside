package FS::part_event::Condition::cust_bill_owed_on_day;

use strict;
use base qw( FS::part_event::Condition );
use Time::Local qw(timelocal);

sub description { 'Amount owed on the invoice on a day last month' };

sub eventtable_hashref {
    { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance over',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
    'day'     => { 'label'      => 'Day of month',
                   'type'       => 'select',
                   'options'    => [ 1..28 ]
                 },
    'age'     => { 'label'      => 'Minimum invoice age on that day',
                   'type'       => 'freq',
                 },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_bill = $object;

  my $over = $self->option('balance');
  $over = 0 unless length($over);

  my $day = $self->option('day');
  my $as_of = $opt{'time'};

  if ( $day ) {
    my ($month, $year) = (localtime($opt{'time'}))[4,5];
    $month--;
    if ( $month < 0 ) {
      $month = 11;
      $year--;
    }
    $as_of = timelocal(0,0,0,$day,$month,$year);
  }

  # check invoice date
  my $age = $self->option_age_from('age', $as_of );
  return 0 if $cust_bill->_date > $age;

  # check balance on the specified day
  my $sql = $cust_bill->owed_sql( $as_of );

  $sql = "SELECT ($sql) FROM cust_bill WHERE invnum = ".$cust_bill->invnum;
  FS::Record->scalar_sql($sql) > $over;
}

# XXX do this if needed
#sub condition_sql { }

1;
