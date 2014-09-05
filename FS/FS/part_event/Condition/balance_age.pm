package FS::part_event::Condition::balance_age;

use strict;
use base qw( FS::part_event::Condition );

sub description { 'Customer balance age'; }

=item check_options OPTIONS

Validate options

=cut

my $duration_rx = qr/^(\d+)$/;
my $unit_rx = qr/^[wmdh]$/;
my $both_rx = qr/^(\d+)([wmdh])/;

sub check_options {
  my ($self, $options) = @_;

  my $age       = $options->{age};
  my $age_units = $options->{age_units};

  return "Invalid (age) must be defined: $age"
    unless( defined $age );

  # over-ride possibly inaccurate unit indicator
  if( $age =~ /$both_rx/ ){
    $age = $1;
    $age_units = $2;
  }

  return "Invalid (age_units) must be defined: $age_units"
    unless defined $age_units;

  return "Invalid (age) must be integer: $age"
    unless( $age =~ /$duration_rx/ );

  return "Invalid (age) must be non-zero: $age"
    if ( $age == 0 );

  return( "Invalid (age_units) must be m/w/d/h: $age_units" )
    unless( $age_units =~ /$unit_rx/i );

  return '';
}

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance over',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
    'age'     => { 'label'      => 'Age',
                   'type'       => 'freq',
                 },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $over = $self->option('balance');
  $over = 0 unless length($over);

  my $age = $self->option_age_from('age', $opt{'time'} );

  $cust_main->balance_date($age) > $over;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $over    = $class->condition_sql_option('balance');
  my $age     = $class->condition_sql_option_age_from('age', $opt{'time'});

  my $balance_sql = FS::cust_main->balance_date_sql( $age );

  "$balance_sql > CAST( $over AS DECIMAL(10,2) )";
}

sub order_sql {
  shift->condition_sql_option_age('age');
}

sub order_sql_weight {
  10;
}

1;
