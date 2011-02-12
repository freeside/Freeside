package FS::part_pkg::sqlradacct_hour;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Base charge plus per-hour (and for data) from an SQL RADIUS radacct table',
  'shortname' => 'Usage charges from RADIUS',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'recur_included_hours' => { 'name' => 'Hours included',
                                'default' => 0,
                              },
    'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                               'default' => 0,
                             },
    'recur_hourly_cap'    => { 'name' => 'Maximum overage charge for hours'.
                                         ' (0 means no cap)',

                               'default' => 0,
                             },

    'recur_included_input' => { 'name' => 'Upload megabytes included',
                                'default' => 0,
                              },
    'recur_input_charge' => { 'name' =>
                                      'Additional charge per megabyte upload',
                              'default' => 0,
                            },
    'recur_input_cap'    => { 'name' => 'Maximum overage charge for upload'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_output' => { 'name' => 'Download megabytes included',
                                 'default' => 0,
                              },
    'recur_output_charge' => { 'name' =>
                                     'Additional charge per megabyte download',
                              'default' => 0,
                            },
    'recur_output_cap'    => { 'name' => 'Maximum overage charge for download'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_total' => { 'name' =>
                                     'Total megabytes included',
                                'default' => 0,
                              },
    'recur_total_charge' => { 'name' =>
                               'Additional charge per megabyte total',
                              'default' => 0,
                            },
    'recur_total_cap'    => { 'name' => 'Maximum overage charge for total'.
                                        ' megabytes (0 means no cap)',
                               'default' => 0,
                             },

    'global_cap'         => { 'name' => 'Global cap on all overage charges'.
                                        ' (0 means no cap)',
                              'default' => 0,
                            },

  },
  'fieldorder' => [qw( recur_included_hours recur_hourly_charge recur_hourly_cap recur_included_input recur_input_charge recur_input_cap recur_included_output recur_output_charge recur_output_cap recur_included_total recur_total_charge recur_total_cap global_cap )],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '\'my $last_bill = $cust_pkg->last_bill; my $hours = $cust_pkg->seconds_since_sqlradacct($last_bill, $sdate ) / 3600 - \' + what.recur_included_hours.value + \'; $hours = 0 if $hours < 0; my $input = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctInputOctets\" ) / 1048576; my $output = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctOutputOctets\" ) / 1048576; my $total = $input + $output - \' + what.recur_included_total.value + \'; $total = 0 if $total < 0; my $input = $input - \' + what.recur_included_input.value + \'; $input = 0 if $input < 0; my $output = $output - \' + what.recur_included_output.value + \'; $output = 0 if $output < 0; my $totalcharge = sprintf(\"%.2f\", \' + what.recur_total_charge.value + \' * $total); my $inputcharge = sprintf(\"%.2f\", \' + what.recur_input_charge.value + \' * $input); my $outputcharge = sprintf(\"%.2f\", \' + what.recur_output_charge.value + \' * $output); my $hourscharge = sprintf(\"%.2f\", \' + what.recur_hourly_charge.value + \' * $hours); if ( \' + what.recur_total_charge.value + \' > 0 ) { push @details, \"Last month\\\'s data \". sprintf(\"%.1f\", $total). \" megs: \\\$$totalcharge\" } if ( \' + what.recur_input_charge.value + \' > 0 ) { push @details, \"Last month\\\'s download \". sprintf(\"%.1f\", $input). \" megs: \\\$$inputcharge\" } if ( \' + what.recur_output_charge.value + \' > 0 ) { push @details, \"Last month\\\'s upload \". sprintf(\"%.1f\", $output). \" megs: \\\$$outputcharge\" } if ( \' + what.recur_hourly_charge.value + \' > 0 ) { push @details, \"Last month\\\'s time \". sprintf(\"%.1f\", $hours). \" hours: \\\$$hourscharge\"; } \' + what.recur_fee.value + \' + $hourscharge + $inputcharge + $outputcharge + $totalcharge ;\'',
  'weight' => 40,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " plus usage" if $str;
    $str;
}

sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $last_bill = $cust_pkg->last_bill;
  my $hours = $cust_pkg->seconds_since_sqlradacct($last_bill, $$sdate ) / 3600;
  $hours -= $self->option('recur_included_hours');
  $hours = 0 if $hours < 0;

  my $input = $cust_pkg->attribute_since_sqlradacct(  $last_bill,
                                                      $$sdate,
                                                      'AcctInputOctets' )
              / 1048576;

  my $output = $cust_pkg->attribute_since_sqlradacct( $last_bill,
                                                      $$sdate,
                                                      'AcctOutputOctets' )
               / 1048576;

  my $total = $input + $output - $self->option('recur_included_total');
  $total = 0 if $total < 0;
  $input = $input - $self->option('recur_included_input');
  $input = 0 if $input < 0;
  $output = $output - $self->option('recur_included_output');
  $output = 0 if $output < 0;

  my $totalcharge =
    $total  * sprintf('%.2f', $self->option('recur_total_charge'));
  $totalcharge = $self->option('recur_total_cap')
    if $self->option('recur_total_cap')
    && $totalcharge > $self->option('recur_total_cap');

  my $inputcharge =
    $input  * sprintf('%.2f', $self->option('recur_input_charge'));
  $inputcharge = $self->option('recur_input_cap')
    if $self->option('recur_input_cap')
    && $inputcharge > $self->option('recur_input_cap');

  my $outputcharge = 
    $output * sprintf('%.2f', $self->option('recur_output_charge'));
  $outputcharge = $self->option('recur_output_cap')
    if $self->option('recur_output_cap')
    && $outputcharge > $self->option('recur_output_cap');

  my $hourscharge =
    $hours * sprintf('%.2f', $self->option('recur_hourly_charge'));
  $hourscharge = $self->option('recur_hourly_cap')
    if $self->option('recur_hourly_cap')
    && $hourscharge > $self->option('recur_hourly_cap');

  if ( $self->option('recur_total_charge') > 0 ) {
    push @$details, "Last month's data ".
                    sprintf('%.1f', $total). " megs: $totalcharge";
  }
  if ( $self->option('recur_input_charge') > 0 ) {
    push @$details, "Last month's download ".
                   sprintf('%.1f', $input). " megs: $inputcharge";
  }
  if ( $self->option('recur_output_charge') > 0 ) {
    push @$details, "Last month's upload ".
                   sprintf('%.1f', $output). " megs: $outputcharge";
  }
  if ( $self->option('recur_hourly_charge')  > 0 ) {
    push @$details, "Last month\'s time ".
                   sprintf('%.1f', $hours). " hours: $hourscharge";
  }

  my $charges = $hourscharge + $inputcharge + $outputcharge + $totalcharge;
  if ( $self->option('global_cap') && $charges > $self->option('global_cap') ) {
    $charges = $self->option('global_cap');
    push @$details, "Usage charges capped at: $charges";
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
