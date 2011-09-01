package FS::part_event::Condition::svc_acct_threshold;

use strict;
use FS::svc_acct;

use base qw( FS::part_event::Condition );

sub description { 'Service is over its usage warning threshold' };

sub eventtable_hashref {
  { 'svc_acct' => 1 }
}

tie my %usage_types, 'Tie::IxHash', (
  'seconds'   => 'Time',
  'upbytes'   => 'Upload',
  'downbytes' => 'Download',
  'totalbytes'=> 'Total transfer',
);

sub option_fields {
  (
    'usage_types' => {
      type          => 'checkbox-multiple',
      options       => [ keys %usage_types ],
      option_labels => \%usage_types,
    },
  );
}

sub condition {
  my($self, $svc_acct) = @_;

  my $types = $self->option('usage_types') || {};
  foreach my $column (keys %$types) {
    # don't trigger if this type of usage isn't tracked on the service
    next if $svc_acct->$column eq '';
    my $threshold;
    my $method = $column.'_threshold';
    $threshold = $svc_acct->$method;
    # don't trigger if seconds = 0 and seconds_threshold is null
    next if $threshold eq '';

    return 1 if ( $svc_acct->$column <= $threshold );
  }
  return 0;
}

sub condition_sql {
  my($self) = @_;

  # not an exact condition_sql--ignores the usage_types option
  '(' . join(' OR ',
    map {
      my $threshold = $_.'_threshold';
      "( svc_acct.$_ IS NOT NULL AND svc_acct.$threshold IS NOT NULL AND ".
      "svc_acct.$_ <= svc_acct.$threshold )"
    } keys %usage_types
  ) . ')'
} 

1;

