package FS::part_pkg::voip_cdr;

use strict;
use vars qw(@ISA $DEBUG %info);
use Date::Format;
use Tie::IxHash;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::flat;
#use FS::rate;
use FS::rate_prefix;

@ISA = qw(FS::part_pkg::flat);

$DEBUG = 1;

tie my %region_method, 'Tie::IxHash',
  'prefix' => 'Rate calls by using destination prefix to look up a region and rate according to the internal prefix and rate tables',
  'upstream_rateid' => 'Rate calls by mapping the upstream rate ID (# rate plan ID?) directly to an internal rate (rate_detail)', #upstream_rateplanid
;

#tie my %cdr_location, 'Tie::IxHash',
#  'internal' => 'Internal: CDR records imported into the internal CDR table',
#  'external' => 'External: CDR records queried directly from an external '.
#                'Asterisk (or other?) CDR table',
#;

%info = (
  'name' => 'VoIP rating by plan of CDR records in an internal (or external?) SQL table',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_flat'     => { 'name' => 'Base recurring fee for this package',
                          'default' => 0,
                        },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'ratenum'   => { 'name' => 'Rate plan',
                     'type' => 'select',
                     'select_table' => 'rate',
                     'select_key'   => 'ratenum',
                     'select_label' => 'ratename',
                   },
    'region_method' => { 'name' => 'Region rating method',
                         'type' => 'select',
                         'select_options' => \%region_method,
                       },

    #XXX also have option for an external db??
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
  'fieldorder' => [qw( setup_fee recur_flat unused_credit ratenum ignore_unrateable )],
  'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

#false laziness w/voip_sqlradacct... resolve it if that one ever gets used again
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $last_bill = $cust_pkg->last_bill;

  my $ratenum = $cust_pkg->part_pkg->option('ratenum');

  my %included_min = ();

  my $charges = 0;

  # also look for a specific domain??? (username@telephonedomain)
  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_acct' } $cust_pkg->cust_svc
  ) {

    foreach my $cdr (
      $cust_svc->get_cdrs( $last_bill, $$sdate )
    ) {
      if ( $DEBUG > 1 ) {
        warn "rating CDR $cdr\n".
             join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
      }

      my( $regionnum, $rate_detail );
      if ( $self->option('region_method') eq 'prefix'
           || ! $self->option('region_method')
         )
      {

        ###
        # look up rate details based on called station id
        ###
  
        my $dest = $cdr->{'calledstationid'};  # XXX
  
        #remove non-phone# stuff and whitespace
        $dest =~ s/\s//g;
        my $proto = '';
        $dest =~ s/^(\w+):// and $proto = $1; #sip:
        my $siphost = '';
        $dest =~ s/\@(.*)$// and $siphost = $1; # @10.54.32.1, @sip.example.com
  
        #determine the country code
        my $countrycode;
        if (    $dest =~ /^011(((\d)(\d))(\d))(\d+)$/
             || $dest =~ /^\+(((\d)(\d))(\d))(\d+)$/
           )
        {
  
          my( $three, $two, $one, $u1, $u2, $rest ) = ( $1,$2,$3,$4,$5,$6 );
          #first look for 1 digit country code
          if ( qsearch('rate_prefix', { 'countrycode' => $one } ) ) {
            $countrycode = $one;
            $dest = $u1.$u2.$rest;
          } elsif ( qsearch('rate_prefix', { 'countrycode' => $two } ) ) { #or 2
            $countrycode = $two;
            $dest = $u2.$rest;
          } else { #3 digit country code
            $countrycode = $three;
            $dest = $rest;
          }
  
        } else {
          $countrycode = '1';
          $dest =~ s/^1//;# if length($dest) > 10;
        }
  
        warn "rating call to +$countrycode $dest\n" if $DEBUG;
  
        #find a rate prefix, first look at most specific (4 digits) then 3, etc.,
        # finally trying the country code only
        my $rate_prefix = '';
        for my $len ( reverse(1..6) ) {
          $rate_prefix = qsearchs('rate_prefix', {
            'countrycode' => $countrycode,
            #'npa'         => { op=> 'LIKE', value=> substr($dest, 0, $len) }
            'npa'         => substr($dest, 0, $len),
          } ) and last;
        }
        $rate_prefix ||= qsearchs('rate_prefix', {
          'countrycode' => $countrycode,
          'npa'         => '',
        });
  
        die "Can't find rate for call to +$countrycode $dest\n"
          unless $rate_prefix;
  
        $regionnum = $rate_prefix->regionnum;
        $rate_detail = qsearchs('rate_detail', {
          'ratenum'        => $ratenum,
          'dest_regionnum' => $regionnum,
        } );
  
        warn "  found rate for regionnum $regionnum ".
             "and rate detail $rate_detail\n"
          if $DEBUG;

      } elsif ( $self->option('region_method') eq 'upstream_rateid' ) { #upstream_rateplanid

        $regionnum = ''; #XXXXX regionnum should be something

        $rate_detail = $cdr->cdr_upstream_rate->rate_detail;

        warn "  found rate for ". #regionnum $regionnum and ".
             "rate detail $rate_detail\n"
          if $DEBUG;

      } else {
        die "don't know how to rate CDRs using method: ".
            $self->option('region_method'). "\n";
      }

      ###
      # find the price and add detail to the invoice
      ###

      $included_min{$regionnum} = $rate_detail->min_included
        unless exists $included_min{$regionnum};

      my $granularity = $rate_detail->sec_granularity;
      my $seconds = $cdr->{'acctsessiontime'}; # XXX
      $seconds += $granularity - ( $seconds % $granularity );
      my $minutes = sprintf("%.1f", $seconds / 60);
      $minutes =~ s/\.0$// if $granularity == 60;

      $included_min{$regionnum} -= $minutes;

      my $charge = 0;
      if ( $included_min{$regionnum} < 0 ) {
        my $charge_min = 0 - $included_min{$regionnum};
        $included_min{$regionnum} = 0;
        $charge = sprintf('%.2f', $rate_detail->min_charge * $charge_min );
        $charges += $charge;
      }

      # XXXXXXX
#      my $rate_region = $rate_prefix->rate_region;
#      warn "  (rate region $rate_region)\n" if $DEBUG;
#
#      my @call_details = (
#        #time2str("%Y %b %d - %r", $session->{'acctstarttime'}),
#        time2str("%c", $cdr->{'acctstarttime'}),  #XXX
#        $minutes.'m',
#        '$'.$charge,
#        "+$countrycode $dest",
#        $rate_region->regionname,
#      );
#
#      warn "  adding details on charge to invoice: ".
#           join(' - ', @call_details )
#        if $DEBUG;
#
#      push @$details, join(' - ', @call_details); #\@call_details,

    } # $cdr

  } # $cust_svc

  $self->option('recur_flat') + $charges;

}

sub is_free {
  0;
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_flat');
}

1;

