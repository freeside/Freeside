package FS::part_event::Condition::pkg_age_before_sales;
use base qw( FS::part_event::Condition::pkg_age_before );

use strict;
use Time::Local qw( timelocal_nocheck );
use FS::Record qw( qsearchs );
use FS::sales_pkg_class;

sub description { 'Package age younger than sales person commission duration'; }

sub option_fields {
  my $class = shift;
  my %option_fields = $class->SUPER::option_fields();

  delete $option_fields{'age'};

  $option_fields{'cust_main_sales'} = {
    'label' => "Compare to the customer sales person if there is no package sales person",
    'type'  => 'checkbox',
    'value' => 'Y',
  };

  %option_fields;
}

sub pkg_age_age {
  my( $self, $cust_pkg, %opt );

  my $salesnum = $cust_pkg->salesnum;
  $salesnum ||= $self->cust_main($cust_pkg)->salesnum
    if $self->option('cust_main_sales');

  return 0 unless $salesnum;

  my $sales_pkg_class = qsearchs( 'sales_pkg_class', {
    'salesnum' => $salesnum,
    'classnum' => $cust_pkg->part_pkg->classnum,
  });

  my $commission_duration = $sales_pkg_class->commission_duration;
  return 0 unless $commission_duration =~ /^\s*(\d+)\s*$/;

  #false laziness w/Condition::option_age_from, but just months

  my $time = $opt{'time'};
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time) )[0,1,2,3,4,5];
  $mon -= $commission_duration;
  until ( $mon >= 0 ) { $mon += 12; $year--; }

  timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);
}

#no working condition_sql for this comparison yet, don't want pkg_age_Common's
sub condition_sql {
  'true';
}

1;
