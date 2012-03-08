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
#use FS::rate_detail;

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

    'ratenum'   => { 'name' => 'Rate plan',
                     'type' => 'select',
                     'select_table' => 'rate',
                     'select_key'   => 'ratenum',
                     'select_label' => 'ratename',
                   },
                   
    'intrastate_ratenum'   => { 'name' => 'Optional alternate intrastate rate plan',
                     'type' => 'select',
                     'select_table' => 'rate',
                     'select_key'   => 'ratenum',
                     'select_label' => 'ratename',
                     'disable_empty' => 0,
                     'empty_label'   => '',
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

    'use_carrierid' => { 'name' => 'Only charge for CDRs where the Carrier ID is set to: ',
                         },

    'use_cdrtypenum' => { 'name' => 'Only charge for CDRs where the CDR Type is set to: ',
                         },
    
    'ignore_cdrtypenum' => { 'name' => 'Do not charge for CDRs where the CDR Type is set to: ',
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

    'skip_dst_length_less' => { 'name' => 'Do not charge for CDRs where the destination is less than this many digits:',
                              },

    'noskip_dst_length_accountcode_tollfree' => { 'name' => 'Do charge for CDRs where dst is less than the specified digits, when accountcode is toll free',
                                                  'type' => 'checkbox',
                                                },

    'skip_lastapp' => { 'name' => 'Do not charge for CDRs where the lastapp matches this value: ',
                      },

    'skip_max_callers' => { 'name' => 'Do not charge for CDRs where max_callers is less than or equal to this value: ',
                          },

    'use_duration'   => { 'name' => 'Calculate usage based on the duration field instead of the billsec field',
                          'type' => 'checkbox',
                        },

    '411_rewrite' => { 'name' => 'Rewrite these (comma-separated) destination numbers to 411 for rating purposes (also ignore any carrierid check): ',
                      },

    #false laziness w/cdr_termination.pm
    'output_format' => { 'name' => 'CDR invoice display format',
                         'type' => 'select',
                         'select_options' => { FS::cdr::invoice_formats() },
                         'default'        => 'default', #XXX test
                       },

    'usage_section' => { 'name' => 'Section in which to place usage charges (whether separated or not): ',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

    'usage_mandate' => { 'name' => 'Always put usage details in separate section',
                          'type' => 'checkbox',
                       },
    #eofalse

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
                       rating_method ratenum intrastate_ratenum 
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
                       ignore_disposition disposition_in
                       skip_dcontext skip_dst_prefix 
                       skip_dstchannel_prefix skip_src_length_more 
                       noskip_src_length_accountcode_tollfree
                       accountcode_tollfree_ratenum
                       skip_dst_length_less
                       noskip_dst_length_accountcode_tollfree
                       skip_lastapp
                       skip_max_callers
                       use_duration
                       411_rewrite
                       output_format usage_mandate summarize_usage usage_section
                       bill_every_call bill_inactive_svcs
                       count_available_phones suspend_bill 
                     )
                  ],
  'weight' => 40,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " plus usage" if $str;
    $str;
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_recur_Common(@_);

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

  my $included_min = $self->option('min_included', 1) || 0; #single price rating
  my $included_calls = $self->option('calls_included', 1) || 0;

  my $cdr_svc_method    = $self->option('cdr_svc_method',1)||'svc_phone.phonenum';
  my $rating_method     = $self->option('rating_method') || 'prefix';
  my $region_group_included_min = $self->option('min_included',1) || 0;
  my %region_group_included_min = ();

  my $output_format     = $self->option('output_format', 'Hush!')
                          || ( $rating_method eq 'upstream_simple'
                                 ? 'simple'
                                 : 'default'
                             );

  my $formatter = FS::detail_format->new($output_format, buffer => $details);

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

    my %options = (
        'disable_src'    => $self->option('disable_src'),
        'default_prefix' => $self->option('default_prefix'),
        'cdrtypenum'     => $self->option('use_cdrtypenum'),
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

    #first rate any outstanding CDRs not yet rated
    foreach my $cdr (
      $svc_x->get_cdrs( %options )
    ) {

      my $error = $cdr->rate(
        'part_pkg'                          => $self,
        'svcnum'                            => $svc_x->svcnum,
        'single_price_included_min'         => \$included_min,
        'region_group_included_min'         => \$region_group_included_min,
        'region_group_included_min_hashref' => \%region_group_included_min,
      );
      die $error if $error; #??

    } # $cdr

    #then add details to invoices & get a total
    $options{'status'} = 'rated';

    foreach my $cdr (
      $svc_x->get_cdrs( %options ) 
    ) {
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
      $formatter->append($cdr);
    }
  }

  $formatter->finish; #writes into $details
  unshift @$details, $formatter->header if @$details;

  $charges;
}

#returns a reason why not to rate this CDR, or false if the CDR is chargeable
sub check_chargable {
  my( $self, $cdr, %flags ) = @_;

  return 'amaflags != 2'
    if $self->option_cacheable('use_amaflags') && $cdr->amaflags != 2;

  return "disposition NOT IN ( $self->option_cacheable('disposition_in') )"
    if $self->option_cacheable('disposition_in') =~ /\S/
    && !grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('disposition_in'));
  
  return "disposition IN ( $self->option_cacheable('ignore_disposition') )"
    if $self->option_cacheable('ignore_disposition') =~ /\S/
    && grep { $cdr->disposition eq $_ } split(/\s*,\s*/, $self->option_cacheable('ignore_disposition'));

  foreach(split(/\s*,\s*/, $self->option_cacheable('skip_dst_prefix'))) {
    return "dst starts with '$_'"
    if length($_) && substr($cdr->dst,0,length($_)) eq $_;
  }

  return "carrierid != $self->option_cacheable('use_carrierid')"
    if length($self->option_cacheable('use_carrierid'))
    && $cdr->carrierid ne $self->option_cacheable('use_carrierid') #ne otherwise 0 matches ''
    && ! $flags{'da_rewrote'};

  # unlike everything else, use_cdrtypenum is applied in FS::svc_x::get_cdrs.
  return "cdrtypenum != $self->option_cacheable('use_cdrtypenum')"
    if length($self->option_cacheable('use_cdrtypenum'))
    && $cdr->cdrtypenum ne $self->option_cacheable('use_cdrtypenum'); #ne otherwise 0 matches ''
  
  return "cdrtypenum == $self->option_cacheable('ignore_cdrtypenum')"
    if length($self->option_cacheable('ignore_cdrtypenum'))
    && $cdr->cdrtypenum eq $self->option_cacheable('ignore_cdrtypenum'); #eq otherwise 0 matches ''

  return "dcontext IN ( $self->option_cacheable('skip_dcontext') )"
    if $self->option_cacheable('skip_dcontext') =~ /\S/
    && grep { $cdr->dcontext eq $_ } split(/\s*,\s*/, $self->option_cacheable('skip_dcontext'));

  my $len_prefix = length($self->option_cacheable('skip_dstchannel_prefix'));
  return "dstchannel starts with $self->option_cacheable('skip_dstchannel_prefix')"
    if $len_prefix
    && substr($cdr->dstchannel,0,$len_prefix) eq $self->option_cacheable('skip_dstchannel_prefix');

  my $dst_length = $self->option_cacheable('skip_dst_length_less');
  return "destination less than $dst_length digits"
    if $dst_length && length($cdr->dst) < $dst_length
    && ! ( $self->option_cacheable('noskip_dst_length_accountcode_tollfree')
            && $cdr->is_tollfree('accountcode')
         );

  return "lastapp is $self->option_cacheable('skip_lastapp')"
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
    map { $count += ( $_->quantity || 0 ) }
      grep { $_->part_svc->svcdb eq 'svc_phone' }
      $cust_pkg->part_pkg->pkg_svc;
  } else {
    $count = 
      scalar(grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc);
  }
  $count;
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

