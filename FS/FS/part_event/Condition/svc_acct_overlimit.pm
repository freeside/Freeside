package FS::part_event::Condition::svc_acct_overlimit;

use strict;
use FS::svc_acct;

use base qw( FS::part_event::Condition );

sub description { 'Service is over its usage limit' };

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

    return 1 if ( $svc_acct->$column <= 0 );
  }
  return 0;
}

sub condition_sql {
  my($self) = @_;

  # not an exact condition_sql--ignores the usage_types option
  '(' . join(' OR ', 
    map {
      "( svc_acct.$_ IS NOT NULL AND svc_acct.$_ <= 0 )"
    } keys %usage_types
  ) . ')'
}

1;

