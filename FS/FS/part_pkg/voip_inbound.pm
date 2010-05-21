package FS::part_pkg::voip_inbound;

use strict;
use vars qw(@ISA $DEBUG %info);
use Date::Format;
use Tie::IxHash;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::recur_Common;
use FS::cdr;
use FS::part_pkg::recur_Common;

@ISA = qw(FS::part_pkg::recur_Common);

$DEBUG = 0;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

tie my %granularity, 'Tie::IxHash', FS::rate_detail::granularities();

%info = (
  'name' => 'VoIP flat rate pricing of CDRs for inbound calls',
  'shortname' => 'VoIP/telco CDR rating (inbound)',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Base recurring fee for this package',
                         'default' => 0,
                       },

    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },

    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },

    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },

    'recur_method'  => { 'name' => 'Recurring fee method',
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },

    'min_charge' => { 'name' => 'Charge per minute',
                    },

    'sec_granularity' => { 'name' => 'Granularity',
                           'type' => 'select',
                           'select_options' => \%granularity,
                         },

    'default_prefix' => { 'name'    => 'Default prefix optionally prepended to customer DID numbers when searching for CDR records',
                          'default' => '+1',
                        },

    'disable_tollfree' => { 'name' => 'Disable automatic toll-free processing',
                            'type' => 'checkbox',
                          },

    'use_amaflags' => { 'name' => 'Do not charge for CDRs where the amaflags field is not set to "2" ("BILL"/"BILLING").',
                        'type' => 'checkbox',
                      },

    'use_disposition' => { 'name' => 'Do not charge for CDRs where the disposition flag is not set to "ANSWERED".',
                           'type' => 'checkbox',
                         },

    'use_disposition_taqua' => { 'name' => 'Do not charge for CDRs where the disposition is not set to "100" (Taqua).',
                                 'type' => 'checkbox',
                               },

    'use_carrierid' => { 'name' => 'Do not charge for CDRs where the Carrier ID is not set to: ',
                         },

    'use_cdrtypenum' => { 'name' => 'Do not charge for CDRs where the CDR Type is not set to: ',
                         },

    'skip_dcontext' => { 'name' => 'Do not charge for CDRs where the dcontext is set to any of these (comma-separated) values:',
                       },

    'skip_dstchannel_prefix' => { 'name' => 'Do not charge for CDRs where the dstchannel starts with:',
                                },

    'skip_dst_length_less' => { 'name' => 'Do not charge for CDRs where the destination is less than this many digits:',
                              },

    'skip_lastapp' => { 'name' => 'Do not charge for CDRs where the lastapp matches this value',
                      },

    'use_duration'   => { 'name' => 'Calculate usage based on the duration field instead of the billsec field',
                          'type' => 'checkbox',
                        },

    #false laziness w/cdr_termination.pm
    'output_format' => { 'name' => 'CDR invoice display format',
                         'type' => 'select',
                         'select_options' => { FS::cdr::invoice_formats() },
                         'default'        => 'default', #XXX test
                       },

    'usage_section' => { 'name' => 'Section in which to place usage charges (whether separated or not)',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

    'usage_mandate' => { 'name' => 'Always put usage details in separate section',
                          'type' => 'checkbox',
                       },
    #eofalse

    'bill_every_call' => { 'name' => 'Generate an invoice immediately for every call.  Useful for prepaid.',
                           'type' => 'checkbox',
                         },

    #XXX also have option for an external db
#    'cdr_location' => { 'name' => 'CDR database location'
#                        'type' => 'select',
#                        'select_options' => \%cdr_location,
#                        'select_callback' => {
#                          'external' => {
#                            'enable' => [ 'datasrc', 'username', 'password' ],
#                          },
#                          'internal' => {
#                            'disable' => [ 'datasrc', 'username', 'password' ],
#                          }
#                        },
#                      },
#    'datasrc' => { 'name' => 'DBI data source for external CDR table',
#                   'disabled' => 'Y',
#                 },
#    'username' => { 'name' => 'External database username',
#                    'disabled' => 'Y',
#                  },
#    'password' => { 'name' => 'External database password',
#                    'disabled' => 'Y',
#                  },

  },
  'fieldorder' => [qw(
                       setup_fee recur_fee recur_temporality unused_credit
                       recur_method cutoff_day
                       min_charge sec_granularity
                       default_prefix
                       disable_tollfree
                       use_amaflags use_disposition
                       use_disposition_taqua use_carrierid use_cdrtypenum
                       skip_dcontext skip_dstchannel_prefix
                       skip_dst_length_less skip_lastapp
                       use_duration
                       output_format usage_mandate summarize_usage usage_section
                       bill_every_call
                       count_available_phones
                     )
                  ],
  'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_recur_Common(@_);

  $charges;

}

sub calc_cancel {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  $self->calc_usage(@_);
}

#false laziness w/voip_sqlradacct calc_recur resolve it if that one ever gets used again

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->option('recur_temporality', 1) eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $spool_cdr = $cust_pkg->cust_main->spool_cdr;

  my %included_min = ();

  my $charges = 0;

#  my $downstream_cdr = '';

  my $disable_tollfree  = $self->option('disable_tollfree');
  my $ignore_unrateable = $self->option('ignore_unrateable', 'Hush!');
  my $use_duration      = $self->option('use_duration');

  my $output_format     = $self->option('output_format', 'Hush!') || 'default';

  #for check_chargable, so we don't keep looking up options inside the loop
  my %opt_cache = ();

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc
  ) {
    my $svc_phone = $cust_svc->svc_x;

    foreach my $cdr ( $svc_phone->get_cdrs(
      'for_update'     => 1,
      'status'         => '', # unprocessed only
      'default_prefix' => $self->option('default_prefix'),
      'inbound'        => 1,
      )
    ) {
      if ( $DEBUG > 1 ) {
        warn "rating inbound CDR $cdr\n".
             join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
      }
      my $granularity = length($self->option('sec_granularity'))
                          ? $self->option('sec_granularity')
                          : 60;

      my $seconds = $use_duration ? $cdr->duration : $cdr->billsec;

      $seconds += $granularity - ( $seconds % $granularity )
        if $seconds      # don't granular-ize 0 billsec calls (bills them)
        && $granularity; # 0 is per call
      my $minutes = sprintf("%.1f",$seconds / 60); 
      $minutes =~ s/\.0$// if $granularity == 60; # count whole minutes, convert to integer
      $minutes = 1 unless $granularity; # per call
      my $charge = sprintf('%.2f', ( $self->option('min_charge') * $minutes )
                                + 0.00000001 ); #so 1.00005 rounds to 1.0001
      next if !$charge;
      $charges += $charge;
      my @call_details = ($cdr->downstream_csv( 'format' => $output_format,
                                             'charge'  => $charge,
                                             'minutes' => $minutes,
                                             'granularity' => $granularity,
                                           )
                        );
      push @$details,
        [ 'C',
          $call_details[0],
          $charge,
          $cdr->calltypenum, #classnum
          $self->phonenum,
          $seconds,
          '', #regionname, not set for inbound calls
        ];

    my $error = $cdr->set_status_and_rated_price( 'done',
                                                  $charge,
                                                  $cust_svc->svcnum,
                                                  'inbound' => 1 );
    die $error if $error;

    } #$cdr
  } # $cust_svc
  unshift @$details, [ 'C',
                       FS::cdr::invoice_header($output_format),
                       '',
                       '',
                       '',
                       '',
                       '',
                     ]
    if @$details;

  $charges;
}

#returns a reason why not to rate this CDR, or false if the CDR is chargeable
sub check_chargable {
  my( $self, $cdr, %flags ) = @_;

  #should have some better way of checking these options from a hash
  #or something

  my @opt = qw(
    use_amaflags
    use_disposition
    use_disposition_taqua
    use_carrierid
    use_cdrtypenum
    skip_dcontext
    skip_dstchannel_prefix
    skip_dst_length_less
    skip_lastapp
  );
  foreach my $opt (grep !exists($flags{option_cache}->{$_}), @opt ) {
    $flags{option_cache}->{$opt} = $self->option($opt, 1);
  }
  my %opt = %{ $flags{option_cache} };

  return 'amaflags != 2'
    if $opt{'use_amaflags'} && $cdr->amaflags != 2;

  return 'disposition != ANSWERED'
    if $opt{'use_disposition'} && $cdr->disposition ne 'ANSWERED';

  return "disposition != 100"
    if $opt{'use_disposition_taqua'} && $cdr->disposition != 100;

  return "carrierid != $opt{'use_carrierid'}"
    if length($opt{'use_carrierid'})
    && $cdr->carrierid ne $opt{'use_carrierid'} #ne otherwise 0 matches ''
    && ! $flags{'da_rewrote'};

  return "cdrtypenum != $opt{'use_cdrtypenum'}"
    if length($opt{'use_cdrtypenum'})
    && $cdr->cdrtypenum ne $opt{'use_cdrtypenum'}; #ne otherwise 0 matches ''

  return "dcontext IN ( $opt{'skip_dcontext'} )"
    if $opt{'skip_dcontext'} =~ /\S/
    && grep { $cdr->dcontext eq $_ } split(/\s*,\s*/, $opt{'skip_dcontext'});

  my $len_prefix = length($opt{'skip_dstchannel_prefix'});
  return "dstchannel starts with $opt{'skip_dstchannel_prefix'}"
    if $len_prefix
    && substr($cdr->dstchannel,0,$len_prefix) eq $opt{'skip_dstchannel_prefix'};

  my $dst_length = $opt{'skip_dst_length_less'};
  return "destination less than $dst_length digits"
    if $dst_length && length($cdr->dst) < $dst_length;

  return "lastapp is $opt{'skip_lastapp'}"
    if length($opt{'skip_lastapp'}) && $cdr->lastapp eq $opt{'skip_lastapp'};

  #all right then, rate it
  '';
}

sub is_free {
  0;
}

#  This equates svc_phone records; perhaps svc_phone should have a field
#  to indicate it represents a line
sub calc_units {    
  my($self, $cust_pkg ) = @_;
  my $count = 0;
  if ( $self->option('count_available_phones', 1)) {
    map { $count += ( $_->quantity || 0 ) }
      grep { $_->part_svc->svcdb eq 'svc_phone' }
      $cust_pkg->part_pkg->pkg_svc;
  } else {
    $count = 
      scalar(grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc);
  }
  $count;
}

1;

