package FS::part_pkg::voip_cdr;

use strict;
use vars qw(@ISA $DEBUG %info);
use Date::Format;
use Tie::IxHash;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::flat;
use FS::cdr;
use FS::rate;
use FS::rate_prefix;
use FS::rate_detail;

@ISA = qw(FS::part_pkg::flat);

$DEBUG = 1;

tie my %rating_method, 'Tie::IxHash',
  'prefix' => 'Rate calls by using destination prefix to look up a region and rate according to the internal prefix and rate tables',
  'upstream' => 'Rate calls based on upstream data: If the call type is "1", map the upstream rate ID directly to an internal rate (rate_detail), otherwise, pass the upstream price through directly.',
  'upstream_simple' => 'Simply pass through and charge the "upstream_price" amount.',
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

%info = (
  'name' => 'VoIP rating by plan of CDR records in an internal (or external) SQL table',
  'shortname' => 'VoIP/telco CDR rating (standard)',
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

    'rating_method' => { 'name' => 'Region rating method',
                         'type' => 'radio',
                         'options' => \%rating_method,
                       },

    'ratenum'   => { 'name' => 'Rate plan',
                     'type' => 'select',
                     'select_table' => 'rate',
                     'select_key'   => 'ratenum',
                     'select_label' => 'ratename',
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

    'use_duration'   => { 'name' => 'Calculate usage based on the duration field instead of the billsec field',
                          'type' => 'checkbox',
                        },

    '411_rewrite' => { 'name' => 'Rewrite these (comma-separated) destination numbers to 411 for rating purposes (also ignore any carrierid check): ',
                      },

    'output_format' => { 'name' => 'CDR invoice display format',
                         'type' => 'select',
                         'select_options' => { FS::cdr::invoice_formats() },
                         'default'        => 'default', #XXX test
                       },

    'usage_section' => { 'name' => 'Section in which to place separate usage charges',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

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
                       rating_method ratenum ignore_unrateable
                       default_prefix
                       disable_src
                       domestic_prefix international_prefix
                       disable_tollfree
                       use_amaflags use_disposition
                       use_disposition_taqua use_carrierid use_cdrtypenum
                       use_duration
                       411_rewrite
                       output_format summarize_usage usage_section
                       bill_every_call
                     )
                  ],
  'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

#false laziness w/voip_sqlradacct calc_recur resolve it if that one ever gets used again
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->option('recur_temporality', 1) eq 'preceding' && $last_bill == 0;

  my $ratenum = $cust_pkg->part_pkg->option('ratenum');

  my $spool_cdr = $cust_pkg->cust_main->spool_cdr;

  my %included_min = ();

  my $charges = 0;

  my $downstream_cdr = '';

  my $rating_method = $self->option('rating_method') || 'prefix';

  my $output_format =
    $self->option('output_format', 'Hush!')
    || ( $rating_method eq 'upstream_simple' ? 'simple' : 'default' );

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc
  ) {

    foreach my $cdr (
      $cust_svc->get_cdrs_for_update( 'disable_src'    => $self->option('disable_src'),
                                      'default_prefix' => $self->option('default_prefix'),
                                    )  # $last_bill, $$sdate )
    ) {
      if ( $DEBUG > 1 ) {
        warn "rating CDR $cdr\n".
             join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
      }

      my $rate_detail;
      my( $rate_region, $regionnum );
      my $pretty_destnum;
      my $charge = '';
      my $classnum = '';
      my @call_details = ();
      if ( $rating_method eq 'prefix' ) {

        my $da_rewrite = 0;
        if ( $self->option('411_rewrite') ) {
          my $dirass = $self->option('411_rewrite');
          $dirass =~ s/\s//g;
          my @dirass = split(',', $dirass);
          if ( grep $cdr->dst eq $_, @dirass ) {
            $cdr->dst('411');
            $da_rewrite = 1;
          }
        }

        my $reason = $self->check_chargable( $cdr,
                                             '411_rewrite' => $da_rewrite,
                                           );

        if ( $reason ) {

          warn "not charging for CDR ($reason)\n" if $DEBUG;
          $charge = 0;

        } else {
          
          ###
          # look up rate details based on called station id
          # (or calling station id for toll free calls)
          ###

          my( $to_or_from, $number );
          if ( $cdr->dst =~ /^(\+?1)?8([02-8])\1/
               && ! $self->option('disable_tollfree')
              )
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

          my $intl = $self->option('international_prefix') || '011';

          #determine the country code
          my $countrycode;
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
            $countrycode = $self->option('domestic_prefix') || '1';
            $number =~ s/^$countrycode//;# if length($number) > 10;
          }

          warn "rating call $to_or_from +$countrycode $number\n" if $DEBUG;
          $pretty_destnum = "+$countrycode $number";

          my $rate = qsearchs('rate', { 'ratenum' => $ratenum })
            or die "ratenum $ratenum not found!";

          $rate_detail = $rate->dest_detail({ 'countrycode' => $countrycode,
                                              'phonenum'    => $number,
                                            });

          if ( $rate_detail ) {

            warn "  found rate for regionnum $regionnum ".
                 "and rate detail $rate_detail\n"
              if $DEBUG;
            $rate_region = $rate_detail->dest_region;
            $regionnum = $rate_region->regionnum;

          } elsif ( $self->option('ignore_unrateable', 1) ) {

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

      } elsif ( $rating_method eq 'upstream' ) { #XXX this was convergent, not currently used.  very much becoming the odd one out. remove?

        if ( $cdr->cdrtypenum == 1 ) { #rate based on upstream rateid

          $rate_detail = $cdr->cdr_upstream_rate->rate_detail;

          $regionnum = $rate_detail->dest_regionnum;
          $rate_region = $rate_detail->dest_region;

          $pretty_destnum = $cdr->dst;

          warn "  found rate for regionnum $regionnum and ".
               "rate detail $rate_detail\n"
            if $DEBUG;

        } else { #pass upstream price through

          $charge = sprintf('%.2f', $cdr->upstream_price);
          $charges += $charge;
 
          @call_details = (
            #time2str("%Y %b %d - %r", $cdr->calldate_unix ),
            time2str("%c", $cdr->calldate_unix),  #XXX this should probably be a config option dropdown so they can select US vs- rest of world dates or whatnot
            'N/A', #minutes...
            '$'.$charge,
            #$pretty_destnum,
            $cdr->description, #$rate_region->regionname,
          );

        }

      } elsif ( $rating_method eq 'upstream_simple' ) {

        #XXX $charge = sprintf('%.2f', $cdr->upstream_price);
        $charge = sprintf('%.3f', $cdr->upstream_price);
        $charges += $charge;

        @call_details = ($cdr->downstream_csv( 'format' => $output_format,
                                               'charge' => $charge,
                                             )
                        );
        $classnum = $cdr->calltypenum;

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

        unless ( @call_details || ( $charge ne '' && $charge == 0 ) ) {

          $included_min{$regionnum} = $rate_detail->min_included
            unless exists $included_min{$regionnum};

          my $granularity = $rate_detail->sec_granularity;

                      # length($cdr->billsec) ? $cdr->billsec : $cdr->duration;
          my $seconds = $self->option('use_duration')
                          ? $cdr->duration
                          : $cdr->billsec;

          $seconds += $granularity - ( $seconds % $granularity )
            if $seconds      # don't granular-ize 0 billsec calls (bills them)
            && $granularity; # 0 is per call
          my $minutes = sprintf("%.1f", $seconds / 60);
          $minutes =~ s/\.0$// if $granularity == 60;

          # per call rather than per minute
          $minutes = 1 unless $granularity;

          $included_min{$regionnum} -= $minutes;

          if ( $included_min{$regionnum} < 0 ) {
            my $charge_min = 0 - $included_min{$regionnum};
            $included_min{$regionnum} = 0;
            $charge = sprintf('%.2f', $rate_detail->min_charge * $charge_min );
            $charges += $charge;
          }

          # this is why we need regionnum/rate_region....
          warn "  (rate region $rate_region)\n" if $DEBUG;

          @call_details = (
           $cdr->downstream_csv( 'format'         => $output_format,
                                 'granularity'    => $granularity,
                                 'minutes'        => $minutes,
                                 'charge'         => $charge,
                                 'pretty_dst'     => $pretty_destnum,
                                 'dst_regionname' => $rate_region->regionname,
                               )
          );

          $classnum = $rate_detail->classnum;

        }

        if ( $charge > 0 ) {
          #just use FS::cust_bill_pkg_detail objects?
          my $call_details;

          #if ( $self->option('rating_method') eq 'upstream_simple' ) {
          if ( scalar(@call_details) == 1 ) {
            $call_details = [ 'C', $call_details[0], $charge, $classnum ];
          } else { #only used for $rating_method eq 'upstream' now
            $csv->combine(@call_details);
            $call_details = [ 'C', $csv->string, $charge, $classnum ];
          }
          warn "  adding details on charge to invoice: [ ".
              join(', ', @{$call_details} ). " ]"
            if ( $DEBUG && ref($call_details) );
          push @$details, $call_details; #\@call_details,
        }

        # if the customer flag is on, call "downstream_csv" or something
        # like it to export the call downstream!
        # XXX price plan option to pick format, or something...
        $downstream_cdr .= $cdr->downstream_csv( 'format' => 'convergent' )
          if $spool_cdr;

        my $error = $cdr->set_status_and_rated_price('done', $charge);
        die $error if $error;

      }

    } # $cdr

  } # $cust_svc

  unshift @$details, [ 'C', FS::cdr::invoice_header($output_format) ]
    if @$details && $rating_method ne 'upstream';

  if ( $spool_cdr && length($downstream_cdr) ) {

    use FS::UID qw(datasrc);
    my $dir = '/usr/local/etc/freeside/export.'. datasrc. '/cdr';
    mkdir $dir, 0700 unless -d $dir;
    $dir .= '/'. $cust_pkg->custnum.
    mkdir $dir, 0700 unless -d $dir;
    my $filename = time2str("$dir/CDR%Y%m%d-spool.CSV", time); #XXX invoice date instead?  would require changing the order things are generated in cust_main::bill insert cust_bill first - with transactions it could be done though

    push @{ $param->{'precommit_hooks'} },
         sub {
               #lock the downstream spool file and append the records 
               use Fcntl qw(:flock);
               use IO::File;
               my $spool = new IO::File ">>$filename"
                 or die "can't open $filename: $!\n";
               flock( $spool, LOCK_EX)
                 or die "can't lock $filename: $!\n";
               seek($spool, 0, 2)
                 or die "can't seek to end of $filename: $!\n";
               print $spool $downstream_cdr;
               flock( $spool, LOCK_UN );
               close $spool;
             };

  } #if ( $spool_cdr && length($downstream_cdr) )

  $charges += $self->option('recur_fee')
    if $param->{'increment_next_bill'};

  $charges;
}

#returns a reason why not to rate this CDR, or false if the CDR is chargeable
sub check_chargable {
  my( $self, $cdr, %opt ) = @_;

  #should have some better way of checking these options from a hash
  #or something

  return 'amaflags != 2'
    if $self->option('use_amaflags') && $cdr->amaflags != 2;

  return 'disposition != ANSWERED'
    if $self->option('use_disposition') && $cdr->disposition ne 'ANSWERED';

  return "disposition != 100"
    if $self->option('use_disposition_taqua') && $cdr->disposition != 100;

  return 'carrierid != '. $self->option('use_carrierid')
    if $self->option('use_carrierid')
    && $cdr->carrierid != $self->option('use_carrierid')
    && ! $opt{'411_rewrite'};

  return 'cdrtypenum != '. $self->option('use_cdrtypenum')
    if $self->option('use_cdrtypenum')
    && $cdr->cdrtypenum != $self->option('use_cdrtypenum');

  #all right then, rate it
  '';
}

sub is_free {
  0;
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

#  This equates svc_phone records; perhaps svc_phone should have a field
#  to indicate it represents a line
sub calc_units {    
  my($self, $cust_pkg ) = @_;
  scalar(grep { $_->part_svc->svcdb eq 'svc_phone' } $cust_pkg->cust_svc);
}

1;

