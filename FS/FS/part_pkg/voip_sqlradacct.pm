package FS::part_pkg::voip_sqlradacct;

use strict;
use vars qw(@ISA %info);
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg;
#use FS::rate;
use FS::rate_prefix;

@ISA = qw(FS::part_pkg);

%info = (
    'name' => 'VoIP rating by plan of CDR records in an SQL RADIUS radacct table',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_flat' => { 'name' => 'Base monthly charge for this package',
                        'default' => 0,
                      },
      'ratenum'   => { 'name' => 'Rate plan',
                       'type' => 'select',
                       'select_table' => 'rate',
                       'select_key'   => 'ratenum',
                       'select_label' => 'ratename',
                     },
    },
    'fieldorder' => [qw( setup_fee recur_flat ratenum )],
    'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

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

      ###
      # look up rate details based on called station id
      ###

      my $dest = $session->{'calledstationid'};

      #remove non-phone# stuff and whitespace
      $dest =~ s/\s//g;
      my $proto = '';
      $dest =~ s/^(\w+):// and $proto = $1; #sip:
      my $ip = '';
      $dest =~ s/\@((\d{1,3}\.){3}\d{1,3})$// and $ip = $1; # @10.54.32.1

      #determine the country code
      my $countrycode;
      if ( $dest =~ /^011((\d\d)(\d))(\d+)$/ ) {

        my( $three, $two, $unknown, $rest ) = ( $1, $2, $3, $4 );
        #first look for 2 digit country code
        if ( qsearch('rate_prefix', { 'countrycode' => $two } ) ) {
          $countrycode = $two;
          $dest = $unknown.$rest;
        } else { #3 digit country code
          $countrycode = $three;
          $dest = $rest;
        }

      } else {
        $countrycode = '1';
      }

      #find a rate prefix, first look at most specific (4 digits) then 3, etc.,
      # finally trying the country code only
      my $rate_prefix = '';
      for my $len ( reverse(1..4) ) {
        $rate_prefix = qsearchs('rate_prefix', {
          'countrycode' => $countrycode,
          'npa'         => { op=> 'LIKE', value=> substr($dest, 0, $len) }
        } ) and last;
      }
      $rate_prefix ||= qsearchs('rate_prefix', {
        'countrycode' => $countrycode,
        'npa'         => '',
      });
      die "Can't find rate for call to countrycode $countrycode number $dest\n"
        unless $rate_prefix;

      my $regionnum = $rate_prefix->regionnum;

      my $rate_detail = qsearchs('rate_detail', {
        'ratenum'        => $ratenum,
        'dest_regionnum' => $regionnum,
      } );

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

      push @$details, 
        #[
        join(' - ', 
          "+$countrycode $dest",
          $rate_prefix->rate_region->regionname,
          $minutes.'m',
          '$'.$charge,
        #]
        )
      ;

    } # $session

  } # $cust_svc

  $self->option('recur_flat') + $charges;

}

sub is_free {
  0;
}

1;

