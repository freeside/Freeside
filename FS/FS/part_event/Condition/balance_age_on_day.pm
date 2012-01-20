package FS::part_event::Condition::balance_age_on_day;

use strict;
use base qw( FS::part_event::Condition );
use Time::Local qw(timelocal);

sub description { 'Customer balance age on a day last month'; }

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
    'age'     => { 'label'      => 'Balance age on that day',
                   'type'       => 'freq',
                 },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

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

  my $age = $self->option_age_from('age', $as_of );

  my $sql = $cust_main->balance_date_sql(
    $age,                 # latest invoice date to consider
    undef,                # earliest invoice date
    'cutoff' => $as_of,   # ignore applications after this date
    'unapplied_date' => 1 # ignore unapplied payments after $age
  );
  $sql = "SELECT ($sql) FROM cust_main WHERE custnum = ".$cust_main->custnum;
  FS::Record->scalar_sql($sql) > $over;
}

# XXX do this if needed
#sub condition_sql { }

1;
