package FS::part_pkg::voip_cdr;

use strict;
use base qw( FS::part_pkg::recur_Common );
use vars qw( $DEBUG %info );
use Date::Format;
use Tie::IxHash;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::cdr;
use FS::rate;
use FS::rate_prefix;
use FS::rate_detail;

use List::Util qw(first min);


$DEBUG = 0;

tie my %cdr_svc_method, 'Tie::IxHash',
  'svc_phone.phonenum' => 'Phone numbers (svc_phone.phonenum)',
  'svc_pbx.title'      => 'PBX name (svc_pbx.title)',
  'svc_pbx.svcnum'     => 'Freeside service # (svc_pbx.svcnum)',
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

%info = (
  'name' => 'VoIP rating by plan of CDR records in an internal (or external) SQL table',
  'shortname' => 'VoIP/telco CDR rating (standard)',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },

    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },
    'add_full_period'=> { 'name' => 'When prorating first month, also bill '.
                                    'for one full period after that',
                          'type' => 'checkbox',
                        },
    'recur_method'  => { 'name' => 'Recurring fee method',
                         #'type' => 'radio',
                         #'options' => \%recur_method,
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },

    'cdr_svc_method' => { 'name' => 'CDR service matching method',
                          'type' => 'radio',
                          'options' => \%cdr_svc_method,
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

    'min_included' => { 'name' => 'Minutes included when using the "single price per minute" rating method or when using the "prefix" rating method ("region group" billing)',
                    },

    'min_charge' => { 'name' => 'Charge per minute when using "single price per minute" rating method',
                    },

    'sec_granularity' => { 'name' => 'Granularity when using "single price per minute" rating method',
                           'type' => 'select',
                           'select_options' => \%granularity,
                         },

    'ignore_unrateable' => { 'name' => 'Ignore calls without a rate in the rate tables.  By default, the system will throw a fatal error upon encountering unrateable calls.',
                             'type' => 'checkbox',
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
                       recur_temporality
                       recur_method cutoff_day
                       add_full_period
                       cdr_svc_method
                       rating_method ratenum min_charge min_included
		       sec_granularity
                       ignore_unrateable
                       default_prefix
                       disable_src
                       domestic_prefix international_prefix
                       disable_tollfree
                       use_amaflags use_disposition
                       use_disposition_taqua use_carrierid use_cdrtypenum
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
                       count_available_phones
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
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $ratenum = $cust_pkg->part_pkg->option('ratenum');

  my $spool_cdr = $cust_pkg->cust_main->spool_cdr;

  my %included_min = ();

  my $charges = 0;

#  my $downstream_cdr = '';

  my $cdr_svc_method    = $self->option('cdr_svc_method',1)||'svc_phone.phonenum';
  my $rating_method     = $self->option('rating_method') || 'prefix';
  my $intl              = $self->option('international_prefix') || '011';
  my $domestic_prefix   = $self->option('domestic_prefix');
  my $disable_tollfree  = $self->option('disable_tollfree');
  my $ignore_unrateable = $self->option('ignore_unrateable', 'Hush!');
  my $use_duration      = $self->option('use_duration');
  my $region_group	= ($rating_method eq 'prefix' && ($self->option('min_included',1) || 0) > 0);
  my $region_group_included_min = $region_group ? $self->option('min_included') : 0;

  my $output_format     = $self->option('output_format', 'Hush!')
                          || ( $rating_method eq 'upstream_simple'
                                 ? 'simple'
                                 : 'default'
                             );

  my @dirass = ();
  if ( $self->option('411_rewrite') ) {
    my $dirass = $self->option('411_rewrite');
    $dirass =~ s/\s//g;
    @dirass = split(',', $dirass);
  }

  my %interval_cache = (); # for timed rates

  #for check_chargable, so we don't keep looking up options inside the loop
  my %opt_cache = ();

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  my($svc_table, $svc_field) = split('\.', $cdr_svc_method);

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
        'status'         => '',
        'for_update'     => 1,
      );  # $last_bill, $$sdate )
    $options{'by_svcnum'} = 1 if $svc_field eq 'svcnum';

    my @invoice_details_sort;

    foreach my $cdr (
      $svc_x->get_cdrs( %options )
    ) {
      if ( $DEBUG > 1 ) {
        warn "rating CDR $cdr\n".
             join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
      }

      my $rate_detail;
      my( $rate_region, $regionnum );
      my $rate;
      my $pretty_destnum;
      my $charge = '';
      my $seconds = '';
      my $weektime = '';
      my $regionname = '';
      my $classnum = '';
      my $countrycode;
      my $number;

      my @call_details = ();
      if ( $rating_method eq 'prefix' ) {

        my $da_rewrote = 0;
        if ( length($cdr->dst) && grep { $cdr->dst eq $_ } @dirass ){
          $cdr->dst('411');
          $da_rewrote = 1;
        }

        my $reason = $self->check_chargable( $cdr,
                                             'da_rewrote'   => $da_rewrote,
                                             'option_cache' => \%opt_cache,
                                           );

        if ( $reason ) {

          warn "not charging for CDR ($reason)\n" if $DEBUG;
          $charge = 0;

        } else {
          
          ###
          # look up rate details based on called station id
          # (or calling station id for toll free calls)
          ###

          my( $to_or_from );
          if ( $cdr->is_tollfree && ! $disable_tollfree )
          { #tollfree call
            $to_or_from = 'from';
            $number = $cdr->src;
          } else { #regular call
            $to_or_from = 'to';
            $number = $cdr->dst;
          }

          warn "parsing call $to_or_from $number\n" if $DEBUG;

          #remove non-phone# stuff and whitespace
          $number =~ s/\s//g;
#          my $proto = '';
#          $dest =~ s/^(\w+):// and $proto = $1; #sip:
#          my $siphost = '';
#          $dest =~ s/\@(.*)$// and $siphost = $1; # @10.54.32.1, @sip.example.com

          #determine the country code
          $countrycode = '';
          if (    $number =~ /^$intl(((\d)(\d))(\d))(\d+)$/
               || $number =~ /^\+(((\d)(\d))(\d))(\d+)$/
             )
          {

            my( $three, $two, $one, $u1, $u2, $rest ) = ( $1,$2,$3,$4,$5,$6 );
            #first look for 1 digit country code
            if ( qsearch('rate_prefix', { 'countrycode' => $one } ) ) {
              $countrycode = $one;
              $number = $u1.$u2.$rest;
            } elsif ( qsearch('rate_prefix', { 'countrycode' => $two } ) ) { #or 2
              $countrycode = $two;
              $number = $u2.$rest;
            } else { #3 digit country code
              $countrycode = $three;
              $number = $rest;
            }

          } else {
            $countrycode = length($domestic_prefix) ? $domestic_prefix : '1';
            $number =~ s/^$countrycode//;# if length($number) > 10;
          }

          warn "rating call $to_or_from +$countrycode $number\n" if $DEBUG;
          $pretty_destnum = "+$countrycode $number";
          #asterisks here causes inserting the detail to barf, so:
          $pretty_destnum =~ s/\*//g;

          my $eff_ratenum = $cdr->is_tollfree('accountcode')
            ? $cust_pkg->part_pkg->option('accountcode_tollfree_ratenum')
            : '';
          $eff_ratenum ||= $ratenum;
          $rate = qsearchs('rate', { 'ratenum' => $eff_ratenum })
            or die "ratenum $eff_ratenum not found!";

          my @ltime = localtime($cdr->startdate);
          $weektime = $ltime[0] + 
                      $ltime[1]*60 +   #minutes
                      $ltime[2]*3600 + #hours
                      $ltime[6]*86400; #days since sunday
          # if there's no timed rate_detail for this time/region combination,
          # dest_detail returns the default.  There may still be a timed rate 
          # that applies after the starttime of the call, so be careful...
          $rate_detail = $rate->dest_detail({ 'countrycode' => $countrycode,
                                              'phonenum'    => $number,
                                              'weektime'    => $weektime,
                                              'cdrtypenum'  => $cdr->cdrtypenum,
                                            });

          if ( $rate_detail ) {

            $rate_region = $rate_detail->dest_region;
            $regionnum = $rate_region->regionnum;
            $regionname = $rate_region->regionname;
            warn "  found rate for regionnum $regionnum ".
                 "and rate detail $rate_detail\n"
              if $DEBUG;

            if ( !exists($interval_cache{$regionnum}) ) {
              my @intervals = (
                sort { $a->stime <=> $b->stime }
                map { my $r = $_->rate_time; $r ? $r->intervals : () }
                $rate->rate_detail
              );
              $interval_cache{$regionnum} = \@intervals;
              warn "  cached ".scalar(@intervals)." interval(s)\n"
                if $DEBUG;
            }

          } elsif ( $ignore_unrateable ) {

            $rate_region = '';
            $regionnum = '';
            #code below will throw a warning & skip

          } else {

            die "FATAL: no rate_detail found in ".
                $rate->ratenum. ":". $rate->ratename. " rate plan ".
                "for +$countrycode $number (CDR acctid ". $cdr->acctid. "); ".
                "add a rate or set ignore_unrateable flag on the package def\n";
          }

        }

      } elsif ( $rating_method eq 'upstream_simple' ) {

        #XXX $charge = sprintf('%.2f', $cdr->upstream_price);
        $charge = sprintf('%.3f', $cdr->upstream_price);
        $charges += $charge;
        warn "Incrementing \$charges by $charge.  Now $charges\n" if $DEBUG;

        @call_details = ($cdr->downstream_csv( 'format' => $output_format,
                                               'charge' => $charge,
                                             )
                        );
        $classnum = $cdr->calltypenum;

      } elsif ( $rating_method eq 'single_price' ) {

        # a little false laziness w/below
        # $rate_detail = new FS::rate_detail({sec_granularity => ... }) ?

        my $granularity = length($self->option('sec_granularity'))
                            ? $self->option('sec_granularity')
                            : 60;

        $seconds = $use_duration ? $cdr->duration : $cdr->billsec;

        $seconds += $granularity - ( $seconds % $granularity )
          if $seconds      # don't granular-ize 0 billsec calls (bills them)
          && $granularity  # 0 is per call
          && $seconds % $granularity;
        my $minutes = $granularity ? ($seconds / 60) : 1;
        $charge = sprintf('%.4f', ( $self->option('min_charge') * $minutes )
                                  + 0.0000000001 ); #so 1.00005 rounds to 1.0001

        warn "Incrementing \$charges by $charge.  Now $charges\n" if $DEBUG;
        $charges += $charge;

        @call_details = ($cdr->downstream_csv( 'format'  => $output_format,
                                               'charge'  => $charge,
                                               'seconds' => ($use_duration ? 
                                                             $cdr->duration : 
                                                             $cdr->billsec),
                                               'granularity' => $granularity,
                                             )
                        );

      } else {
        die "don't know how to rate CDRs using method: $rating_method\n";
      }

      ###
      # find the price and add detail to the invoice
      ###

      # if $rate_detail is not found, skip this CDR... i.e. 
      # don't add it to invoice, don't set its status to done,
      # don't call downstream_csv or something on it...
      # but DO emit a warning...
      #if ( ! $rate_detail && ! scalar(@call_details) ) {}
      if ( ! $rate_detail && $charge eq '' ) {

        warn "no rate_detail found for CDR.acctid: ". $cdr->acctid.
             "; skipping\n"

      } else { # there *is* a rate_detail (or call_details), proceed...
        # About this section:
        # We don't round _anything_ (except granularizing) 
        # until the final $charge = sprintf("%.2f"...).

        unless ( @call_details || ( $charge ne '' && $charge == 0 ) ) {

          my $seconds_left = $use_duration ? $cdr->duration : $cdr->billsec;
          # charge for the first (conn_sec) seconds
          $seconds = min($seconds_left, $rate_detail->conn_sec);
          $seconds_left -= $seconds; 
          $weektime     += $seconds;
          $charge = $rate_detail->conn_charge; 

          my $etime;
          while($seconds_left) {
            my $ratetimenum = $rate_detail->ratetimenum; # may be empty

            # find the end of the current rate interval
            if(@{ $interval_cache{$regionnum} } == 0) {
              # There are no timed rates in this group, so just stay 
              # in the default rate_detail for the entire duration.
              # Set an "end" of 1 past the end of the current call.
              $etime = $weektime + $seconds_left + 1;
            } 
            elsif($ratetimenum) {
              # This is a timed rate, so go to the etime of this interval.
              # If it's followed by another timed rate, the stime of that 
              # interval should match the etime of this one.
              my $interval = $rate_detail->rate_time->contains($weektime);
              $etime = $interval->etime;
            }
            else {
              # This is a default rate, so use the stime of the next 
              # interval in the sequence.
              my $next_int = first { $_->stime > $weektime } 
                              @{ $interval_cache{$regionnum} };
              if ($next_int) {
                $etime = $next_int->stime;
              }
              else {
                # weektime is near the end of the week, so decrement 
                # it by a full week and use the stime of the first 
                # interval.
                $weektime -= (3600*24*7);
                $etime = $interval_cache{$regionnum}->[0]->stime;
              }
            }

            my $charge_sec = min($seconds_left, $etime - $weektime);

            $seconds_left -= $charge_sec;

            $included_min{$regionnum}{$ratetimenum} = $rate_detail->min_included
              unless exists $included_min{$regionnum}{$ratetimenum};

            my $granularity = $rate_detail->sec_granularity;

            my $minutes;
            if ( $granularity ) { # charge per minute
              # Round up to the nearest $granularity
              if ( $charge_sec and $charge_sec % $granularity ) {
                $charge_sec += $granularity - ($charge_sec % $granularity);
              }
              $minutes = $charge_sec / 60; #don't round this
            }
            else { # per call
              $minutes = 1;
              $seconds_left = 0;
            }

            $seconds += $charge_sec;

	    $region_group_included_min -= $minutes if $region_group;

            $included_min{$regionnum}{$ratetimenum} -= $minutes;
            if ( $region_group_included_min <= 0
			  && $included_min{$regionnum}{$ratetimenum} <= 0 ) {
              my $charge_min = 0 - $included_min{$regionnum}{$ratetimenum}; #XXX should preserve
                                                              #(display?) this
              $included_min{$regionnum}{$ratetimenum} = 0;
              $charge += ($rate_detail->min_charge * $charge_min); #still not rounded
            }

            # choose next rate_detail
            $rate_detail = $rate->dest_detail({ 'countrycode' => $countrycode,
                                                'phonenum'    => $number,
                                                'weektime'    => $etime,
                                                'cdrtypenum'  => $cdr->cdrtypenum })
                    if($seconds_left);
            # we have now moved forward to $etime
            $weektime = $etime;

          } #while $seconds_left
          # this is why we need regionnum/rate_region....
          warn "  (rate region $rate_region)\n" if $DEBUG;

          $classnum = $rate_detail->classnum;
          $charge = sprintf('%.2f', $charge + 0.000001); # NOW round it.
          warn "Incrementing \$charges by $charge.  Now $charges\n" if $DEBUG;
          $charges += $charge;

          @call_details = (
            $cdr->downstream_csv( 'format'         => $output_format,
                                  'granularity'    => $rate_detail->sec_granularity, 
                                  'seconds'        => ($use_duration ?
                                                       $cdr->duration :
                                                       $cdr->billsec),
                                  'charge'         => $charge,
                                  'pretty_dst'     => $pretty_destnum,
                                  'dst_regionname' => $regionname,
                                )
          );
        } #if(there is a rate_detail)
 

        if ( $charge > 0 ) {
          #just use FS::cust_bill_pkg_detail objects?
          my $call_details;
          my $phonenum = $svc_x->phonenum;

          if ( scalar(@call_details) == 1 ) {
            $call_details =
              [ 'C',
                $call_details[0],
                $charge,
                $classnum,
                $phonenum,
                $seconds,
                $regionname,
              ];
          } else { #only used for $rating_method eq 'upstream' now
            $csv->combine(@call_details);
            $call_details =
              [ 'C',
                $csv->string,
                $charge,
                $classnum,
                $phonenum,
                $seconds,
                $regionname,
              ];
          }
          warn "  adding details on charge to invoice: [ ".
              join(', ', @{$call_details} ). " ]"
            if ( $DEBUG && ref($call_details) );
          push @invoice_details_sort, [ $call_details, $cdr->calldate_unix ];
        }

        # if the customer flag is on, call "downstream_csv" or something
        # like it to export the call downstream!
        # XXX price plan option to pick format, or something...
        #$downstream_cdr .= $cdr->downstream_csv( 'format' => 'XXX format' )
        #  if $spool_cdr;

        my $error = $cdr->set_status_and_rated_price( 'done',
                                                      $charge,
                                                      $cust_svc->svcnum,
                                                    );
        die $error if $error;

      }

    } # $cdr
 
    my @sorted_invoice_details = sort { @{$a}[1] <=> @{$b}[1] } @invoice_details_sort;
    foreach my $sorted_call_detail ( @sorted_invoice_details ) {
        push @$details, @{$sorted_call_detail}[0];
    }

  } # $cust_svc

  unshift @$details, [ 'C',
                       FS::cdr::invoice_header($output_format),
                       '',
                       '',
                       '',
                       '',
                       '',
                     ]
    if @$details && $rating_method ne 'upstream';

#  if ( $spool_cdr && length($downstream_cdr) ) {
#
#    use FS::UID qw(datasrc);
#    my $dir = '/usr/local/etc/freeside/export.'. datasrc. '/cdr';
#    mkdir $dir, 0700 unless -d $dir;
#    $dir .= '/'. $cust_pkg->custnum.
#    mkdir $dir, 0700 unless -d $dir;
#    my $filename = time2str("$dir/CDR%Y%m%d-spool.CSV", time); #XXX invoice date instead?  would require changing the order things are generated in cust_main::bill insert cust_bill first - with transactions it could be done though
#
#    push @{ $param->{'precommit_hooks'} },
#         sub {
#               #lock the downstream spool file and append the records 
#               use Fcntl qw(:flock);
#               use IO::File;
#               my $spool = new IO::File ">>$filename"
#                 or die "can't open $filename: $!\n";
#               flock( $spool, LOCK_EX)
#                 or die "can't lock $filename: $!\n";
#               seek($spool, 0, 2)
#                 or die "can't seek to end of $filename: $!\n";
#               print $spool $downstream_cdr;
#               flock( $spool, LOCK_UN );
#               close $spool;
#             };
#
#  } #if ( $spool_cdr && length($downstream_cdr) )

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
    skip_dst_prefix
    skip_dcontext
    skip_dstchannel_prefix
    skip_src_length_more noskip_src_length_accountcode_tollfree
    skip_dst_length_less noskip_dst_length_accountcode_tollfree
    skip_lastapp
    skip_max_callers
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

  foreach(split(',',$opt{'skip_dst_prefix'})) {
    return "dst starts with '$_'"
    if length($_) && substr($cdr->dst,0,length($_)) eq $_;
  }

  return "dcontext IN ( $opt{'skip_dcontext'} )"
    if $opt{'skip_dcontext'} =~ /\S/
    && grep { $cdr->dcontext eq $_ } split(/\s*,\s*/, $opt{'skip_dcontext'});

  my $len_prefix = length($opt{'skip_dstchannel_prefix'});
  return "dstchannel starts with $opt{'skip_dstchannel_prefix'}"
    if $len_prefix
    && substr($cdr->dstchannel,0,$len_prefix) eq $opt{'skip_dstchannel_prefix'};

  my $dst_length = $opt{'skip_dst_length_less'};
  return "destination less than $dst_length digits"
    if $dst_length && length($cdr->dst) < $dst_length
    && ! ( $opt{'noskip_dst_length_accountcode_tollfree'}
            && $cdr->is_tollfree('accountcode')
         );

  return "lastapp is $opt{'skip_lastapp'}"
    if length($opt{'skip_lastapp'}) && $cdr->lastapp eq $opt{'skip_lastapp'};

  my $src_length = $opt{'skip_src_length_more'};
  if ( $src_length ) {

    if ( $opt{'noskip_src_length_accountcode_tollfree'} ) {

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

  return "max_callers <= $opt{skip_max_callers}"
    if length($opt{'skip_max_callers'})
      and length($cdr->max_callers)
      and $cdr->max_callers <= $opt{'skip_max_callers'};

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

