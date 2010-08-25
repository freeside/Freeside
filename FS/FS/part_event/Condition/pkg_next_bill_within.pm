package FS::part_event::Condition::pkg_next_bill_within;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Next bill date within upcoming interval';
}

# Run the event when the next bill date is within X days.
# To clarify, that's within X days _after_ the current date,
# not before.
# Combine this with a "once_every" condition so that the event
# won't repeat every day until the bill date.

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  (
    'within'  =>  { 'label'   => 'Bill date within',
                    'type'    => 'freq',
                  },
    # possibly "field" to allow date fields besides 'bill'?
  );
}

sub condition {
  my( $self, $cust_pkg, %opt ) = @_;

  my $pkg_date = $cust_pkg->get('bill') or return 0;
  $pkg_date = $self->option_age_from('within', $pkg_date );

  $opt{'time'} >= $pkg_date;

}

#XXX write me for efficiency
sub condition_sql {
  my ($self, $table, %opt) = @_;
  $opt{'time'}.' >= '.
    $self->condition_sql_option_age_from('within', 'cust_pkg.bill')
}

1;

