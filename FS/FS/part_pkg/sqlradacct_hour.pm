package FS::part_pkg::sqlradacct_hour;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;

@ISA = qw(FS::part_pkg);

%info = (
    'name' => 'Base charge plus per-hour (and for data) from an SQL RADIUS radacct table',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_flat' => { 'name' => 'Base monthly charge for this package',
                        'default' => 0,
                      },
      'recur_included_hours' => { 'name' => 'Hours included',
                                  'default' => 0,
                                },
      'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                                 'default' => 0,
                               },
      'recur_included_input' => { 'name' => 'Upload megabytes included',
                                  'default' => 0,
                                },
      'recur_input_charge' => { 'name' =>
                                        'Additional charge per megabyte upload',
                                'default' => 0,
                              },
      'recur_included_output' => { 'name' => 'Download megabytes included',
                                   'default' => 0,
                                },
      'recur_output_charge' => { 'name' =>
                                       'Additional charge per megabyte download',
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
    },
    'fieldorder' => [qw( setup_fee recur_flat recur_included_hours recur_hourly_charge recur_included_input recur_input_charge recur_included_output recur_output_charge recur_included_total recur_total_charge )],
    #'setup' => 'what.setup_fee.value',
    #'recur' => '\'my $last_bill = $cust_pkg->last_bill; my $hours = $cust_pkg->seconds_since_sqlradacct($last_bill, $sdate ) / 3600 - \' + what.recur_included_hours.value + \'; $hours = 0 if $hours < 0; my $input = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctInputOctets\" ) / 1048576; my $output = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctOutputOctets\" ) / 1048576; my $total = $input + $output - \' + what.recur_included_total.value + \'; $total = 0 if $total < 0; my $input = $input - \' + what.recur_included_input.value + \'; $input = 0 if $input < 0; my $output = $output - \' + what.recur_included_output.value + \'; $output = 0 if $output < 0; my $totalcharge = sprintf(\"%.2f\", \' + what.recur_total_charge.value + \' * $total); my $inputcharge = sprintf(\"%.2f\", \' + what.recur_input_charge.value + \' * $input); my $outputcharge = sprintf(\"%.2f\", \' + what.recur_output_charge.value + \' * $output); my $hourscharge = sprintf(\"%.2f\", \' + what.recur_hourly_charge.value + \' * $hours); if ( \' + what.recur_total_charge.value + \' > 0 ) { push @details, \"Last month\\\'s data \". sprintf(\"%.1f\", $total). \" megs: \\\$$totalcharge\" } if ( \' + what.recur_input_charge.value + \' > 0 ) { push @details, \"Last month\\\'s download \". sprintf(\"%.1f\", $input). \" megs: \\\$$inputcharge\" } if ( \' + what.recur_output_charge.value + \' > 0 ) { push @details, \"Last month\\\'s upload \". sprintf(\"%.1f\", $output). \" megs: \\\$$outputcharge\" } if ( \' + what.recur_hourly_charge.value + \' > 0 ) { push @details, \"Last month\\\'s time \". sprintf(\"%.1f\", $hours). \" hours: \\\$$hourscharge\"; } \' + what.recur_flat.value + \' + $hourscharge + $inputcharge + $outputcharge + $totalcharge ;\'',
    'weight' => 40,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
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
  my $inputcharge =
    $input  * sprintf('%.2f', $self->option('recur_input_charge'));
  my $outputcharge = 
    $output * sprintf('%.2f', $self->option('recur_output_charge'));

  my $hourscharge =
    $hours * sprintf('%.2f', $self->option('recur_hourly_charge'));

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

  $self->option('recur_flat')
    + $hourscharge + $inputcharge + $outputcharge + $totalcharge;
}

1;
