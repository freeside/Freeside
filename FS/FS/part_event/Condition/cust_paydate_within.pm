package FS::part_event::Condition::cust_paydate_within;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( str2time_sql str2time_sql_closing );
use Time::Local 'timelocal';

sub description {
  'Credit card expires within upcoming interval';
}

# Run the event when the customer's credit card expiration 
# date is less than X days in the future.
# Combine this with a "once_every" condition so that the event
# won't repeat every day until the expiration date.

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 0,
      'cust_pkg'  => 0,
    };
}

sub option_fields {
  (
    'within'  =>  { 'label'   => 'Expiration date within',
                    'type'    => 'freq',
                  },
  );
}

sub condition {
  my( $self, $cust_main, %opt ) = @_;
  my $expire_time = $cust_main->paydate_epoch or return 0;
  $opt{'time'} >= $self->option_age_from('within', $expire_time);
}

sub condition_sql {
  my ($self, $table, %opt) = @_;
  my $expire_time = FS::cust_main->paydate_epoch_sql or return 'true';
  $opt{'time'} . ' >= ' .  
    $self->condition_sql_option_age_from('within', $expire_time);
}

1;

