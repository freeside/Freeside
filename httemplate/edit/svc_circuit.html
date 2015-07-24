<& elements/svc_Common.html,
              'table'              => 'svc_circuit',
              'fields'             => \@fields,
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my @fields = (
  { field         => 'providernum',
    type          => 'select-table',
    table         => 'circuit_provider',
    name_col      => 'provider',
    disable_empty => 1,
  },
  { field         => 'typenum',
    type          => 'select-table',
    table         => 'circuit_type',
    name_col      => 'typename',
    disable_empty => 1,
  },
  { field         => 'termnum',
    type          => 'select-table',
    table         => 'circuit_termination',
    name_col      => 'termination',
    disable_empty => 1,
  },
  { field         => 'circuit_id',
    size          => 40,
  },
  { field         => 'desired_due_date',
    type          => 'input-date-field',
  },
  { field         => 'due_date',
    type          => 'input-date-field',
  },
  'vendor_order_id',
  'vendor_qual_id',
  'vendor_order_status',
  'endpoint_ip_addr',
  { field         => 'endpoint_mac_addr',
    type          => 'input-mac_addr',
  },
);

# needed: a new_callback to migrate vendor quals over to circuits

#my ($svc_new_callback, $svc_edit_callback, $svc_error_callback);

</%init>
