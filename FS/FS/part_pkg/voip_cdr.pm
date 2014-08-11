package FS::part_pkg::voip_cdr;
use base qw( FS::part_pkg::recur_Common );

use strict;
use vars qw( $DEBUG %info );
use Tie::IxHash;
use Date::Format;
use Text::CSV_XS;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::cdr;
use FS::detail_format;
#use FS::rate;
#use FS::rate_prefix;
#use FS::rate_detail; #for ::granularities

$DEBUG = 0;

tie my %cdr_svc_method, 'Tie::IxHash',
  'svc_phone.phonenum' => 'Phone numbers (svc_phone.phonenum)',
  'svc_pbx.title'      => 'PBX name (svc_pbx.title)',
  'svc_pbx.svcnum'     => 'Freeside service # (svc_pbx.svcnum)',
  'svc_pbx.ip.src'     => 'PBX name to source IP address',
  'svc_pbx.ip.dst'     => 'PBX name to destination IP address',
;

tie my %rating_method, 'Tie::IxHash',
  'prefix' => 'Rate calls by using destination prefix to look up a region and rate according to the internal prefix and rate tables',
#  'upstream' => 'Rate calls based on upstream data: If the call type is "1", map the upstream rate ID directly to an internal rate (rate_detail), otherwise, pass the upstream price through directly.',
  'upstream_simple' => 'Simply pass through and charge the "upstream_price" amount.',
  'single_price' => 'A single price per minute for all calls.',
;

tie my %rounding, 'Tie::IxHash',
  '2' => 'Two decimal places (cent)',
  '4' => 'Four decimal places (100th of a cent)',
;

#tie my %cdr_location, 'Tie::IxHash',
#  'internal' => 'Internal: CDR records imported into the internal CDR table',
#  'external' => 'External: CDR records queried directly from an external '.
#                'Asterisk (or other?) CDR table',
#;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

tie my %granularity, 'Tie::IxHash', FS::rate_detail::granularities();

# previously "1" was "ignore"
tie my %unrateable_opts, 'Tie::IxHash',
  '' => 'Exit with a fatal error',
  1  => 'Ignore and continue',
  2  => 'Flag for later review',
;

tie my %detail_formats, 'Tie::IxHash',
  '' => '',
  FS::cdr::invoice_formats()
;

tie my %accountcode_tollfree_field, 'Tie::IxHash',
  'dst' => 'Destination (dst)',
  'src' => 'Source (src)',
;

%info = (
  'name' => 'VoIP rating by plan of CDR records in an internal (or external) SQL table',
  'shortname' => 'VoIP/telco CDR rating (standard)',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    'suspend_bill' => { 'name' => 'Continue recurring billing while suspended',
                        'type' => 'checkbox',
                      },
    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },

    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },
    'recur_method'  => { 'name' => 'Recurring fee method',
                         #'type' => 'radio',
                         #'options' => \%recur_method,
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },

    'cdr_svc_method' => { 'name' => 'CDR service matching method',
#                          'type' => 'radio',
                          'type' => 'select',
                          'select_options' => \%cdr_svc_method,
                        },

    'rating_method' => { 'name' => 'Rating method',
                         'type' => 'radio',
                         'options' => \%rating_method,
                       },

    'rounding' => { 'name' => 'Rounding for destination prefix rating',
                    'type' => 'select',
                    'select_options' => \%rounding,
                  },

    'ratenum'   => { 'name' => 'Rate plan',
                     'type' => 'select-rate',
                   },
                   
    'intrastate_ratenum'   => { 'name' => 'Optional alternate intrastate rate plan',
                     'type' => 'select-rate',
                     'disable_empty' => 0,
                     'empty_label'   => ' ',
                   },

    'calls_included' => { 'name' => 'Number of calls included at no usage charge', },

    'min_included' => { 'name' => 'Minutes included when using the "single price per minute" or "prefix" rating method',
                    },

    'min_charge' => { 'name' => 'Charge per minute when using "single price per minute" rating method',
                    },

    'sec_granularity' => { 'name' => 'Granularity when using "single price per minute" rating method',
                           'type' => 'select',
                           'select_options' => \%granularity,
                         },

    'ignore_unrateable' => { 'name' => 'Handling of calls without a rate in the rate table',
                             'type' => 'select',
                             'select_options' => \%unrateable_opts,
                           },

    'default_prefix' => { 'name'    => 'Default prefix optionally prepended to customer DID numbers when searching for CDR records',
                          'default' => '+1',
                        },

    'disable_src' => { 'name' => 'Disable rating of CDR records based on the "src" field in addition to "charged_party"',
                       'type' => 'checkbox'
                     },

    'domestic_prefix' => { 'name'    => 'Destination prefix for domestic CDR records',
                           'default' => '1',
                         },

#    'domestic_prefix_required' => { 'name' => 'Require explicit destination prefix for domestic CDR records',
#                                    'type' => 'checkbox',
#                                  },

    'international_prefix' => { 'name'    => 'Destination prefix for international CDR records',
                                'default' => '011',
                              },

    'disable_tollfree' => { 'name' => 'Disable automatic toll-free processing',
                            'type' => 'checkbox',
                          },

    'use_amaflags' => { 'name' => 'Only charge for CDRs where the amaflags field is set to "2" ("BILL"/"BILLING").',
                        'type' => 'checkbox',
                      },

    'use_carrierid' => { 'name' => 'Only charge for CDRs where the Carrier ID is set to any of these (comma-separated) values: ',
                         },

    'use_cdrtypenum' => { 'name' => 'Only charge for CDRs where the CDR Type is set to this cdrtypenum: ',
                         },
    
    'ignore_cdrtypenum' => { 'name' => 'Do not charge for CDRs where the CDR Type is set to this cdrtypenum: ',
                         },

    'use_calltypenum' => { 'name' => 'Only charge for CDRs where the CDR Call Type is set to this calltypenum: ',
                         },
    
    'ignore_calltypenum' => { 'name' => 'Do not charge for CDRs where the CDR Call Type is set to this calltypenum: ',
                         },
    
    'ignore_disposition' => { 'name' => 'Do not charge for CDRs where the Disposition is set to any of these (comma-separated) values: ',
                         },
    
    'disposition_in' => { 'name' => 'Only charge for CDRs where the Disposition is set to any of these (comma-separated) values: ',
                         },

    'skip_dst_prefix' => { 'name' => 'Do not charge for CDRs where the destination number starts with any of these values: ',
    },

    'skip_dcontext' => { 'name' => 'Do not charge for CDRs where the dcontext is set to any of these (comma-separated) values: ',
                       },

    'skip_dstchannel_prefix' => { 'name' => 'Do not charge for CDRs where the dstchannel starts with:',
                                },

    'skip_src_length_more' => { 'name' => 'Do not charge for CDRs where the source is more than this many digits:',
                              },

    'noskip_src_length_accountcode_tollfree' => { 'name' => 'Do charge for CDRs where source is equal or greater than the specified digits, when accountcode is toll free',
                                                  'type' => 'checkbox',
                                                },

    'accountcode_tollfree_ratenum' => {
      'name' => 'Optional alternate rate plan when accountcode is toll free: ',
      'type' => 'select',
      'select_table'  => 'rate',
      'select_key'    => 'ratenum',
      'select_label'  => 'ratename',
      'disable_empty' => 0,
      'empty_label'   => '',
    },

    'accountcode_tollfree_field' => {
      'name'           => 'When using an alternate rate plan for toll-free accountcodes, the CDR field to use in rating calculations',
      'type'           => 'select',
      'select_options' => \%accountcode_tollfree_field,
    },

    'skip_dst_length_less' => { 'name' => 'Do not charge for CDRs where the destination is less than this many digits:',
                              },

    'noskip_dst_length_accountcode_tollfree' => { 'name' => 'Do charge for CDRs where dst is less than the specified digits, when accountcode is toll free',
                                                  'type' => 'checkbox',
                                                },

    'skip_lastapp' => { 'name' => 'Do not charge for CDRs where the lastapp matches this value: ',
                      },

    'skip_max_callers' => { 'name' => 'Do not charge for CDRs where max_callers is less than or equal to this value: ',
                          },

    'skip_same_customer' => {
      'name' => 'Do not charge for calls between numbers belonging to the same customer',
      'type' => 'checkbox',
    },

    'use_duration'   => { 'name' => 'Calculate usage based on the duration field instead of the billsec field',
                          'type' => 'checkbox',
                        },

    '411_rewrite' => { 'name' => 'Rewrite these (comma-separated) destination numbers to 411 for rating purposes (also ignore any carrierid check): ',
                      },

    #false laziness w/cdr_termination.pm
    'output_format' => { 'name' => 'CDR display format for invoices',
                         'type' => 'select',
                         'select_options' => \%detail_formats,
                         'default'        => 'default', #XXX test
                       },

    'selfservice_format' => 
      { 'name' => 'CDR display format for selfservice',
        'type' => 'select',
        'select_options' => \%detail_formats,
        'default' => 'default'
      },
    'selfservice_inbound_format' =>
      { 'name' => 'Inbound CDR display format for selfservice',
        'type' => 'select',
        'select_options' => \%detail_formats,
        'default' => ''
      },

    'usage_section' => { 'name' => 'Section in which to place usage charges (whether separated or not): ',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

    'usage_mandate' => { 'name' => 'Always put usage details in separate section.  The section is defined in the next option.',
                          'type' => 'checkbox',
                       },
    #eofalse

    'usage_showzero' => { 'name' => 'Show details for included / no-charge calls.',
                        'type' => 'checkbox',
                      },

    'bill_every_call' => { 'name' => 'Generate an invoice immediately for every call (as well any setup fee, upon first payment).  Useful for prepaid.',
                           'type' => 'checkbox',
                         },

    'bill_inactive_svcs' => { 'name' => 'Bill for all phone numbers that were active during the billing period',
                              'type' => 'checkbox',
                            },

    'count_available_phones' => { 'name' => 'Consider for tax purposes the number of lines to be svc_phones that may be provisioned rather than those that actually are.',
                           'type' => 'checkbox',
                         },

    #XXX also have option for an external db?  these days we suck them into ours
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
                       recur_temporality
                       recur_method cutoff_day ),
                       FS::part_pkg::prorate_Mixin::fieldorder,
                    qw(
                       cdr_svc_method
                       rating_method rounding ratenum intrastate_ratenum 
                       calls_included
                       min_charge min_included sec_granularity
                       ignore_unrateable
                       default_prefix
                       disable_src
                       domestic_prefix international_prefix
                       disable_tollfree
                       use_amaflags
                       use_carrierid 
                       use_cdrtypenum ignore_cdrtypenum
                       use_calltypenum ignore_calltypenum
                       ignore_disposition disposition_in
                       skip_dcontext skip_dst_prefix 
                       skip_dstchannel_prefix skip_src_length_more 
                       noskip_src_length_accountcode_tollfree
                       accountcode_tollfree_ratenum accountcode_tollfree_field
                       skip_dst_length_less
                       noskip_dst_length_accountcode_tollfree
                       skip_lastapp
                       skip_max_callers
                       skip_same_customer
                       use_duration
                       411_rewrite
                       output_format 
                       selfservice_format selfservice_inbound_format
                       usage_mandate usage_section summarize_usage 
                       usage_showzero bill_every_call bill_inactive_svcs
                       count_available_phones suspend_bill 
                     )
                  ],
  'weight' => 41,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info(@_);
    $str .= " plus usage" if $str;
    $str;
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += ($cust_pkg->quantity || 1) * $self->calc_recur_Common(@_);

  $charges;

}

# use the default
#sub calc_cancel {
#  my $self = shift;
#  my($cust_pkg, $sdate, $details, $param ) = @_;
#
#  $self->calc_usage(@_);
#}

#false laziness w/voip_sqlradacct calc_recur resolve it if that one ever gets used again

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $charges = 0;

  my $included_min = $self->option('min_included', 1) || 0;
    #single price rating
    #or region group

  my $included_calls = $self->option('calls_included', 1) || 0;

  my $cdr_svc_method    = $self->option('cdr_svc_method',1)||'svc_phone.phonenum';
  my $rating_method     = $self->option('rating_method') || 'prefix';
  my %detail_included_min = ();

  my $output_format     = $self->option('output_format', 'Hush!')
                          || ( $rating_method eq 'upstream_simple'
                                 ? 'simple'
                                 : 'default'
                             );

  my $usage_showzero    = $self->option('usage_showzero', 1);

  my $formatter = FS::detail_format->new($output_format,
    buffer => $details,
    locale => $cust_pkg->cust_main->locale
  );

  my $use_duration = $self->option('use_duration');

  my($svc_table, $svc_field, $by_ip_addr) = split('\.', $cdr_svc_method);

  my @cust_svc;
  if( $self->option('bill_inactive_svcs',1) ) {
    #XXX in this mode do we need to restrict the set of CDRs by date also?
    @cust_svc = $cust_pkg->h_cust_svc($$sdate, $last_bill);
  }
  else {
    @cust_svc = $cust_pkg->cust_svc;
  }
  @cust_svc = grep { $_->part_svc->svcdb eq $svc_table } @cust_svc;

  foreach my $cust_svc (@cust_svc) {

    my $svc_x;
    if( $self->option('bill_inactive_svcs',1) ) {
      $svc_x = $cust_svc->h_svc_x($$sdate, $last_bill);
    }
    else {
      $svc_x = $cust_svc->svc_x;
    }

    unless ( $svc_x ) {
      my $h = $self->option('bill_inactive_svcs',1) ? 'h_' : '';
      warn "WARNING: no $h$svc_table for svcnum ". $cust_svc->svcnum. "\n";
    }

    my %options = (
        'disable_src'    => $self->option('disable_src',1),
        'default_prefix' => $self->option('default_prefix',1),
        'cdrtypenum'     => $self->option('use_cdrtypenum',1),
        'calltypenum'    => $self->option('use_calltypenum',1),
        'status'         => '',
        'for_update'     => 1,
      );  # $last_bill, $$sdate )
    if ( $svc_field eq 'svcnum' ) {
      $options{'by_svcnum'} = 1;
    }
    elsif ($svc_table eq 'svc_pbx' and $svc_field eq 'ip') {
      $options{'by_ip_addr'} = $by_ip_addr;
    }

    #my @invoice_details_sort;

    # for tagging invoice details
    my $phonenum;
    if ( $svc_table eq 'svc_phone' ) {
      $phonenum = $svc_x->phonenum;
    } elsif ( $svc_table eq 'svc_pbx' ) {
      $phonenum = $svc_x->title;
    }
    $formatter->phonenum($phonenum);

    #first rate any outstanding CDRs not yet rated
    # XXX eventually use an FS::Cursor for this
    my $cdr_search = $svc_x->psearch_cdrs(%options);
    $cdr_search->limit(1000);
    $cdr_search->increment(0); # because we're changing their status as we go
    while ( my $cdr = $cdr_search->fetch ) {

      my $error = $cdr->rate(
        'part_pkg'                          => $self,
        'cust_pkg'                          => $cust_pkg,
        'svcnum'                            => $svc_x->svcnum,
        'plan_included_min'                 => \$included_min,
        'detail_included_min_hashref'       => \%detail_included_min,
      );
      die $error if $error; #??

      $cdr_search->adjust(1) if $cdr->freesidestatus eq '';
      # it was skipped without changing status, so increment the 
      # offset so that we don't re-fetch it on refill

    } # $cdr

    #then add details to invoices & get a total
    $options{'status'} = 'rated';

    $cdr_search = $svc_x->psearch_cdrs(%options);
    $cdr_search->limit(1000);
    $cdr_search->increment(0);
    while ( my $cdr = $cdr_search->fetch ) {
      my $error;
      # at this point we officially Do Not Care about the rating method
      if ( $included_calls > 0 ) {
        $included_calls--;
        #$charges += 0, obviously
        #but don't set the rated price to zero--there should be a record
        $error = $cdr->set_status('no-charge');
      }
      else {
        $charges += $cdr->rated_price;
        $error = $cdr->set_status('done');
      }
      die $error if $error;
      $formatter->append($cdr)
        unless $cdr->rated_price == 0 and not $usage_showzero;

      $cdr_search->adjust(1) if $cdr->freesidestatus eq 'rated';
    } #$cdr
  }

  $formatter->finish; #writes into $details
  unshift @$details, $formatter->header if @$details;

  $charges;
}

#returns a reason why not to rate this CDR, or false if the CDR is chargeable
# lots of false laziness w/voip_inbound
sub check_chargable {
  my( $self, $cdr, %flags ) = @_;

  return 'amaflags != 2'
    if $self->option_cacheable('use_amaflags') && $cdr->amaflags != 2;

  return "disposition NOT IN ( ". $self->option_cacheable('disposition_in')." )"
    if $self->option_cacheable('disposition_in') =~ /\S/
    && !grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('disposition_in'));
  
  return "disposition IN ( ". $self->option_cacheable('ignore_disposition')." )"
    if $self->option_cacheable('ignore_disposition') =~ /\S/
    && grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('ignore_disposition'));

  foreach(split(/\s*,\s*/, $self->option_cacheable('skip_dst_prefix'))) {
    return "dst starts with '$_'"
    if length($_) && substr($cdr->dst,0,length($_)) eq $_;
  }

  return "carrierid NOT IN ( ". $self->option_cacheable('use_carrierid'). " )"
    if $self->option_cacheable('use_carrierid') =~ /\S/
    && ! $flags{'da_rewrote'} #why?
    && !grep { $cdr->carrierid eq $_ } split(/\s*,\s*/, $self->option_cacheable('use_carrierid')); #eq otherwise 0 matches ''

  # unlike everything else, use_cdrtypenum is applied in FS::svc_x::get_cdrs.
  return "cdrtypenum != ". $self->option_cacheable('use_cdrtypenum')
    if length($self->option_cacheable('use_cdrtypenum'))
    && $cdr->cdrtypenum ne $self->option_cacheable('use_cdrtypenum'); #ne otherwise 0 matches ''
  
  return "cdrtypenum == ". $self->option_cacheable('ignore_cdrtypenum')
    if length($self->option_cacheable('ignore_cdrtypenum'))
    && $cdr->cdrtypenum eq $self->option_cacheable('ignore_cdrtypenum'); #eq otherwise 0 matches ''

  # unlike everything else, use_calltypenum is applied in FS::svc_x::get_cdrs.
  return "calltypenum != ". $self->option_cacheable('use_calltypenum')
    if length($self->option_cacheable('use_calltypenum'))
    && $cdr->calltypenum ne $self->option_cacheable('use_calltypenum'); #ne otherwise 0 matches ''
  
  return "calltypenum == ". $self->option_cacheable('ignore_calltypenum')
    if length($self->option_cacheable('ignore_calltypenum'))
    && $cdr->calltypenum eq $self->option_cacheable('ignore_calltypenum'); #eq otherwise 0 matches ''

  return "dcontext IN ( ". $self->option_cacheable('skip_dcontext'). " )"
    if $self->option_cacheable('skip_dcontext') =~ /\S/
    && grep { $cdr->dcontext eq $_ } split(/\s*,\s*/, $self->option_cacheable('skip_dcontext'));

  my $len_prefix = length($self->option_cacheable('skip_dstchannel_prefix'));
  return "dstchannel starts with ". $self->option_cacheable('skip_dstchannel_prefix')
    if $len_prefix
    && substr($cdr->dstchannel,0,$len_prefix) eq $self->option_cacheable('skip_dstchannel_prefix');

  my $dst_length = $self->option_cacheable('skip_dst_length_less');
  return "destination less than $dst_length digits"
    if $dst_length && length($cdr->dst) < $dst_length
    && ! ( $self->option_cacheable('noskip_dst_length_accountcode_tollfree')
            && $cdr->is_tollfree('accountcode')
         );

  return "lastapp is ". $self->option_cacheable('skip_lastapp')
    if length($self->option_cacheable('skip_lastapp')) && $cdr->lastapp eq $self->option_cacheable('skip_lastapp');

  my $src_length = $self->option_cacheable('skip_src_length_more');
  if ( $src_length ) {

    if ( $self->option_cacheable('noskip_src_length_accountcode_tollfree') ) {

      if ( $cdr->is_tollfree('accountcode') ) {
        return "source less than or equal to $src_length digits"
          if length($cdr->src) <= $src_length;
      } else {
        return "source more than $src_length digits"
          if length($cdr->src) > $src_length;
      }

    } else {
      return "source more than $src_length digits"
        if length($cdr->src) > $src_length;
    }

  }

  return "max_callers <= ". $self->option_cacheable('skip_max_callers')
    if length($self->option_cacheable('skip_max_callers'))
      and length($cdr->max_callers)
      and $cdr->max_callers <= $self->option_cacheable('skip_max_callers');

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
    foreach my $pkg_svc ($cust_pkg->part_pkg->pkg_svc) {
      if ($pkg_svc->part_svc->svcdb eq 'svc_phone') { # svc_pbx?
        $count += $pkg_svc->quantity || 0;
      }
    }
    $count *= $cust_pkg->quantity;
  } else {
    $count = 
      scalar(grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc);
  }
  $count;
}

sub reset_usage {
  my ($self, $cust_pkg, %opt) = @_;
  my @part_pkg_usage = $self->part_pkg_usage or return '';
  warn "  resetting usage minutes\n" if $opt{debug};
  my %cust_pkg_usage = map { $_->pkgusagepart, $_ } $cust_pkg->cust_pkg_usage;
  foreach my $part_pkg_usage (@part_pkg_usage) {
    my $part = $part_pkg_usage->pkgusagepart;
    my $usage = $cust_pkg_usage{$part} ||
                FS::cust_pkg_usage->new({
                    'pkgnum'        => $cust_pkg->pkgnum,
                    'pkgusagepart'  => $part,
                    'minutes'       => $part_pkg_usage->minutes,
                });
    foreach my $cdr_usage (
      qsearch('cdr_cust_pkg_usage', {'cdrusagenum' => $usage->cdrusagenum})
    ) {
      my $error = $cdr_usage->delete;
      warn "  error resetting CDR usage: $error\n";
    }

    if ( $usage->pkgusagenum ) {
      if ( $part_pkg_usage->rollover ) {
        $usage->set('minutes', $part_pkg_usage->minutes + $usage->minutes);
      } else {
        $usage->set('minutes', $part_pkg_usage->minutes);
      }
      my $error = $usage->replace;
      warn "  error resetting usage minutes: $error\n" if $error;
    } else {
      my $error = $usage->insert;
      warn "  error resetting usage minutes: $error\n" if $error;
    }
  } #foreach $part_pkg_usage
}

# tells whether cust_bill_pkg_detail should return a single line for 
# each phonenum
sub sum_usage {
  my $self = shift;
  $self->option('output_format') =~ /^sum_/;
}

# and whether cust_bill should show a detail line for the service label 
# (separate from usage details)
sub hide_svc_detail {
  my $self = shift;
  $self->option('output_format') =~ /^sum_/;
}


1;

