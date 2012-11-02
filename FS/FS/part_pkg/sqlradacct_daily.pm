package FS::part_pkg::sqlradacct_hour;
use base qw( FS::part_pkg::flat );

use strict;
use vars qw(%info);
use Time::Local qw( timelocal timelocal_nocheck );
#use FS::Record qw(qsearch qsearchs);

%info = (
  'name' => 'Time and data charges from an SQL RADIUS radacct table, with per-day limits',
  'shortname' => 'Daily usage charges from RADIUS',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'recur_included_hours' => { 'name' => 'Hours included per day',
                                'default' => 0,
                              },
    'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                               'default' => 0,
                             },
    'recur_hourly_cap'    => { 'name' => 'Maximum daily charge for hours'.
                                         ' (0 means no cap)',

                               'default' => 0,
                             },

    'recur_included_input' => { 'name' => 'Upload megabytes included per day',
                                'default' => 0,
                              },
    'recur_input_charge' => { 'name' =>
                                      'Additional charge per megabyte upload',
                              'default' => 0,
                            },
    'recur_input_cap'    => { 'name' => 'Maximum daily charge for upload'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_output' => { 'name' => 'Download megabytes included per day',
                                 'default' => 0,
                              },
    'recur_output_charge' => { 'name' =>
                                     'Additional charge per megabyte download',
                              'default' => 0,
                            },
    'recur_output_cap'    => { 'name' => 'Maximum daily charge for download'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_total' => { 'name' =>
                                     'Total megabytes included per day',
                                'default' => 0,
                              },
    'recur_total_charge' => { 'name' =>
                               'Additional charge per megabyte total',
                              'default' => 0,
                            },
    'recur_total_cap'    => { 'name' => 'Maximum daily charge for total'.
                                        ' megabytes (0 means no cap)',
                               'default' => 0,
                             },

    'global_cap'         => { 'name' => 'Daily cap on all overage charges'.
                                        ' (0 means no cap)',
                              'default' => 0,
                            },

  },
  'fieldorder' => [qw( recur_included_hours recur_hourly_charge recur_hourly_cap recur_included_input recur_input_charge recur_input_cap recur_included_output recur_output_charge recur_output_cap recur_included_total recur_total_charge recur_total_cap )], #global_cap )],
  'weight' => 41,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " plus usage" if $str;
    $str;
}

#hacked-up false laziness w/sqlradacct_hour,
# but keeping it separate to start  with is safer for existing folks
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $last_bill = $cust_pkg->last_bill;

  my $charges = 0;

  #loop over each day starting with last_bill inclusive (since we generated a
  # bill that day, we didn't have a full picture of the day's usage)
  # and ending with sdate exclusive (same reason)

  my($l_day, $l_mon, $l_year) = (localtime($last_bill))[3,5];
  my $day_start = timelocal(0,0,0, $l_day, $l_mon, $l_year);

  my($s_day, $s_mon, $s_year) = (localtime($$sdate))[3,5];
  my $billday_start = timelocal(0,0,0, $s_day, $s_mon, $s_year);

  while ( $day_start < $billday_start ) {

    my($day, $mon, $year) = (localtime($day_start))[3,5];
    my $tomorrow = timelocal_nocheck(0,0,0, $day+1, $mon, $year);

    #afact the usage methods already use the lower bound inclusive and the upper
    # exclusive, so no need for $tomorrow-1
    my @range = ( $day_start, $tomorrow );
                                           
    my $hours = $cust_pkg->seconds_since_sqlradacct(@range) / 3600;
    $hours -= $self->option('recur_included_hours');
    $hours = 0 if $hours < 0;

    my $input = $cust_pkg->attribute_since_sqlradacct( @range,
                                                       'AcctInputOctets')
                / 1048576;

    my $output = $cust_pkg->attribute_since_sqlradacct( @range,
                                                        'AcctOutputOctets' )
                 / 1048576;

    my $total = $input + $output - $self->option('recur_included_total');
    $total = 0 if $total < 0;
    $input = $input - $self->option('recur_included_input');
    $input = 0 if $input < 0;
    $output = $output - $self->option('recur_included_output');
    $output = 0 if $output < 0;

    my $totalcharge =
       sprintf('%.2f', $total * $self->option('recur_total_charge'));
    $totalcharge = $self->option('recur_total_cap')
      if $self->option('recur_total_cap')
      && $totalcharge > $self->option('recur_total_cap');

    my $inputcharge =
       sprintf('%.2f', $input * $self->option('recur_input_charge'));
    $inputcharge = $self->option('recur_input_cap')
      if $self->option('recur_input_cap')
      && $inputcharge > $self->option('recur_input_cap');

    my $outputcharge = 
      sprintf('%.2f', $output * $self->option('recur_output_charge'));
    $outputcharge = $self->option('recur_output_cap')
      if $self->option('recur_output_cap')
      && $outputcharge > $self->option('recur_output_cap');

    my $hourscharge =
      sprintf('%.2f', $hours * $self->option('recur_hourly_charge'));
    $hourscharge = $self->option('recur_hourly_cap')
      if $self->option('recur_hourly_cap')
      && $hourscharge > $self->option('recur_hourly_cap');

    my $fordate = time2str('for %a %b %o, %Y', $day_start);

    if ( $self->option('recur_total_charge') > 0 ) {
      push @$details, "Data $fordate ".
                      sprintf('%.1f', $total). " megs: $totalcharge";
    }
    if ( $self->option('recur_input_charge') > 0 ) {
      push @$details, "Download $fordate ".
                     sprintf('%.1f', $input). " megs: $inputcharge";
    }
    if ( $self->option('recur_output_charge') > 0 ) {
      push @$details, "Upload $fordate".
                     sprintf('%.1f', $output). " megs: $outputcharge";
    }
    if ( $self->option('recur_hourly_charge')  > 0 ) {
      push @$details, "Time $fordate ".
                     sprintf('%.1f', $hours). " hours: $hourscharge";
    }

    my $daily_charges = $hourscharge + $inputcharge + $outputcharge + $totalcharge;
    if ( $self->option('global_cap') && $charges > $self->option('global_cap') ) {
      $charges = $self->option('global_cap');
      push @$details, "Usage charges $fordate capped at: $charges";
    }

    $charges += $daily_charges;

    $day_start = $tomorrow;
  }

  $self->option('recur_fee') + $charges;
}

sub can_discount { 0; }

sub is_free_options {
  qw( setup_fee recur_fee recur_hourly_charge
      recur_input_charge recur_output_charge recur_total_charge );
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

1;
