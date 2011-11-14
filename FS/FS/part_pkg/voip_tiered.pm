package FS::part_pkg::voip_tiered;
use base qw( FS::part_pkg::voip_cdr );

use strict;
use vars qw( $DEBUG %info );
use Tie::IxHash;
use Date::Format;
use Text::CSV_XS;
use FS::Conf;
use FS::Record qw(qsearchs); # qsearch);
use FS::cdr;
use FS::rate_tier;
use FS::rate_detail;

use Data::Dumper;

$DEBUG = 0;

tie my %cdr_inout, 'Tie::IxHash',
  'outbound'         => 'Outbound',
  'inbound'          => 'Inbound',
  'outbound_inbound' => 'Outbound and Inbound',
;

tie my %granularity, 'Tie::IxHash', FS::rate_detail::granularities();

%info = (
  'name' => 'VoIP tiered rate pricing of CDRs',
  'shortname' => 'VoIP/telco CDR tiered rating',
  'inherit_fields' => [ 'voip_cdr', 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    'tiernum' => { 'name' => 'Tier plan',
                   'type' => 'select',
                   'select_table' => 'rate_tier',
                   'select_key'   => 'tiernum',
                   'select_label' => 'tiername',
                 },
    'cdr_inout' => { 'name'=> 'Call direction when using phone number matching',
                     'type'=> 'select',
                     'select_options' => \%cdr_inout,
                   },
    'min_included' => { 'name' => 'Minutes included',
                    },
    'sec_granularity' => { 'name' => 'Granularity',
                           'type' => 'select',
                           'select_options' => \%granularity,
                         },
    'rating_method'                          => { 'disabled' => 1 },
    'ratenum'                                => { 'disabled' => 1 },
    'intrastate_ratenum'                     => { 'disabled' => 1 },
    'min_charge'                             => { 'disabled' => 1 },
    'ignore_unrateable'                      => { 'disabled' => 1 },
    'domestic_prefix'                        => { 'disabled' => 1 },
    'international_prefix'                   => { 'disabled' => 1 },
    'disable_tollfree'                       => { 'disabled' => 1 },
    'noskip_src_length_accountcode_tollfree' => { 'disabled' => 1 },
    'accountcode_tollfree_ratenum'           => { 'disabled' => 1 },
    'noskip_dst_length_accountcode_tollfree' => { 'disabled' => 1 },
  },
  'fieldorder' => [qw(
                       recur_temporality
                       recur_method cutoff_day ),
                       FS::part_pkg::prorate_Mixin::fieldorder,
                   qw(
                       cdr_svc_method cdr_inout
                       tiernum
                     )
                  ],
  'weight' => 44,
);

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $included_min    = $self->option('min_included', 1) || 0;
  my $cdr_svc_method  = $self->option('cdr_svc_method',1)||'svc_phone.phonenum';
  my $cdr_inout       = ($cdr_svc_method eq 'svc_phone.phonenum')
                          && $self->option('cdr_inout',1)
                          || 'outbound';
  my $use_duration    = $self->option('use_duration');
  my $granularity     = length($self->option('sec_granularity'))
                          ? $self->option('sec_granularity')
                          : 60;

  #for check_chargable, so we don't keep looking up options inside the loop
  my %opt_cache = ();

  my($svc_table, $svc_field) = split('\.', $cdr_svc_method);

  my %options = (
    'disable_src'    => $self->option('disable_src'),
    'default_prefix' => $self->option('default_prefix'),
    'status'         => '',
    'for_update'     => 1,
  );  # $last_bill, $$sdate )
  $options{'by_svcnum'} = 1 if $svc_field eq 'svcnum';

  ###
  # pass one: find the total minutes/calls and store the CDRs
  ###
  my $total = 0;
  my @cdrs = ();

  my @cust_svc;
  if( $self->option('bill_inactive_svcs',1) ) {
    #XXX in this mode do we need to restrict the set of CDRs by date also?
    @cust_svc = $cust_pkg->h_cust_svc($$sdate, $last_bill);
  } else {
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

    foreach my $pass (split('_', $cdr_inout)) {

      $options{'inbound'} = ( $pass eq 'inbound' );

      foreach my $cdr (
        $svc_x->get_cdrs( %options )
      ) {
        if ( $DEBUG > 1 ) {
          warn "rating CDR $cdr\n".
               join('', map { "  $_ => ". $cdr->{$_}. "\n" } keys %$cdr );
        }

        my $charge = '';
        my $seconds = '';

        $seconds = $use_duration ? $cdr->duration : $cdr->billsec;

        $seconds += $granularity - ( $seconds % $granularity )
          if $seconds      # don't granular-ize 0 billsec calls (bills them)
          && $granularity  # 0 is per call
          && $seconds % $granularity;
        my $minutes = $granularity ? ($seconds / 60) : 1;

        my $charge_min = $minutes;

        $included_min -= $minutes;
        if ( $included_min > 0 ) {
          $charge_min = 0;
        } else {
           $charge_min = 0 - $included_min;
           $included_min = 0;
        }

        $cdr->tmp_inout( $pass );
        $cdr->tmp_rated_seconds( $seconds );
        $cdr->tmp_rated_minutes( $charge_min );
        $cdr->tmp_svcnum( $cust_svc->svcnum );
        push @cdrs, $cdr;
        $total += $charge_min;

      } # $cdr

    } # $pass
 
  } # $cust_svc

  ###
  # pass two: find a tiered rate and do the rest
  ###

  my $rate_tier = qsearchs('rate_tier', { tiernum=>$self->option('tiernum') } )
    or die "unknown tiernum ". $self->option('tiernum');
  my $rate_tier_detail = $rate_tier->rate_tier_detail( $total )
    or die "no base rate for tier? ($total)";
  my $min_charge = $rate_tier_detail->min_charge;

  my $output_format = $self->option('output_format', 'Hush!') || 'default';

  my $csv = new Text::CSV_XS;

  my $charges = 0;
  my @invoice_details_sort;

  foreach my $cdr (@cdrs) {

    my $charge_min = $cdr->tmp_rated_minutes;

    my $charge = sprintf('%.4f', ( $min_charge * $charge_min )
                                 + 0.0000000001 ); #so 1.00005 rounds to 1.0001


    if ( $charge > 0 ) {
      $charges += $charge;

      my $detail = 
        $cdr->downstream_csv( 'format'  => $output_format,
                              'charge'  => $charge,
                              'seconds' => ($use_duration ? 
                                              $cdr->duration : 
                                              $cdr->billsec),
                              'granularity' => $granularity,
                            );

      my $call_details =
        { format      => 'C',
          detail      => $detail,
          amount      => $charge,
          #classnum    => $cdr->calltypenum, #classnum
          #phonenum    => $phonenum, #XXX need this to sort on them
          accountcode => $cdr->accountcode,
          startdate   => $cdr->startdate,
          duration    => $cdr->tmp_rated_seconds,
        };

       #warn "  adding details on charge to invoice: [ ".
      #    join(', ', @{$call_details} ). " ]"
      #  if ( $DEBUG && ref($call_details) );
      push @invoice_details_sort, [ $call_details, $cdr->calldate_unix ];
    }

    my $error = $cdr->set_status_and_rated_price(
      'done',
      $charge,
      $cdr->tmp_svcnum,
      'inbound'       => ($cdr->tmp_inout eq 'inbound'),
      'rated_minutes' => $charge_min,
      'rated_seconds' => $cdr->tmp_rated_seconds,
    );
    die $error if $error;


  }

  my @sorted_invoice_details = sort { ${$a}[1] <=> ${$b}[1] } @invoice_details_sort;
  foreach my $sorted_call_detail ( @sorted_invoice_details ) {
      push @$details, ${$sorted_call_detail}[0];
  }

  unshift @$details, { format => 'C',
                       detail => FS::cdr::invoice_header($output_format),
                     }
    if @$details;

  $charges;
}

1;

