package FS::part_pkg::voip_sqlradacct;

use strict;
use vars qw(@ISA $DEBUG %info);
use Date::Format;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::flat;
#use FS::rate;
use FS::rate_prefix;

@ISA = qw(FS::part_pkg::flat);

$DEBUG = 1;

%info = (
  'disabled' => 1, #they're sucked into our CDR table now instead
  'name' => 'VoIP rating by plan of CDR records in an SQL RADIUS radacct table',
  'shortname' => 'VoIP/telco CDR rating (external RADIUS)',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Base recurring fee for this package',
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
  },
  'fieldorder' => [qw( setup_fee recur_fee unused_credit ratenum ignore_unrateable )],
  'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

#false laziness w/voip_cdr... resolve it if this one ever gets used again
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $last_bill = $cust_pkg->last_bill;

  my $ratenum = $cust_pkg->part_pkg->option('ratenum');

  my %included_min = ();

  my $charges = 0;

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_acct' } $cust_pkg->cust_svc
  ) {

    foreach my $session (
      $cust_svc->get_session_history( $last_bill, $$sdate )
    ) {
      if ( $DEBUG > 1 ) {
        warn "rating session $session\n".
             join('', map { "  $_ => ". $session->{$_}. "\n" } keys %$session );
      }

      ###
      # look up rate details based on called station id
      ###

      my $dest = $session->{'calledstationid'};

      #remove non-phone# stuff and whitespace
      $dest =~ s/\s//g;
      my $proto = '';
      $dest =~ s/^(\w+):// and $proto = $1; #sip:
      my $siphost = '';
      $dest =~ s/\@(.*)$// and $siphost = $1; # @10.54.32.1, @sip.example.com

      #determine the country code
      my $countrycode;
      if ( $dest =~ /^011(((\d)(\d))(\d))(\d+)$/ ) {

        my( $three, $two, $one, $u1, $u2, $rest ) = ( $1, $2, $3, $4, $5, $6 );
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

      my $regionnum = $rate_prefix->regionnum;
      my $rate_detail = qsearchs('rate_detail', {
        'ratenum'        => $ratenum,
        'dest_regionnum' => $regionnum,
      } );

      warn "  found rate for regionnum $regionnum ".
           "and rate detail $rate_detail\n"
        if $DEBUG;

      ###
      # find the price and add detail to the invoice
      ###

      $included_min{$regionnum} = $rate_detail->min_included
        unless exists $included_min{$regionnum};

      my $granularity = $rate_detail->sec_granularity;
      my $seconds = $session->{'acctsessiontime'};
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

      my $rate_region = $rate_prefix->rate_region;
      warn "  (rate region $rate_region)\n" if $DEBUG;

      my @call_details = (
        #time2str("%Y %b %d - %r", $session->{'acctstarttime'}),
        time2str("%c", $session->{'acctstarttime'}),
        $minutes.'m',
        '$'.$charge,
        "+$countrycode $dest",
        $rate_region->regionname,
      );

      warn "  adding details on charge to invoice: ".
           join(' - ', @call_details )
        if $DEBUG;

      push @$details, join(' - ', @call_details); #\@call_details,

    } # $session

  } # $cust_svc

  $self->option('recur_fee') + $charges;

}

sub can_discount { 0; }

sub is_free { 0; }

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

1;

