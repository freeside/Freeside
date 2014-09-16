package FS::part_pkg::sqlradacct_hour;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

# some constants to facilitate changes
# maybe we display charge per petabyte in the future?
use constant KB => 1024;
use constant MB => KB * 1024;
use constant GB => MB * 1024;
use constant BU => GB;            # base unit
use constant BS => 'gigabyte';    # BU spelled out
use constant BA => 'gig';         # BU abbreviation

%info = (
  'name' => 'Time and data charges from an SQL RADIUS radacct table',
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

    'recur_included_input' => { 'name' => 'Upload ' . BS . 's included',
                                'default' => 0,
                              },
    'recur_input_charge' => { 'name' =>
                                      'Additional charge per ' . BS . ' upload',
                              'default' => 0,
                            },
    'recur_input_cap'    => { 'name' => 'Maximum overage charge for upload'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_output' => { 'name' => 'Download ' . BS . 's included',
                                 'default' => 0,
                              },
    'recur_output_charge' => { 'name' =>
                                     'Additional charge per ' . BS . ' download',
                              'default' => 0,
                            },
    'recur_output_cap'    => { 'name' => 'Maximum overage charge for download'.
                                         ' (0 means no cap)',
                               'default' => 0,
                             },

    'recur_included_total' => { 'name' =>
                                     'Total ' . BS . 's included',
                                'default' => 0,
                              },
    'recur_total_charge' => { 'name' =>
                               'Additional charge per ' . BS . ' total',
                              'default' => 0,
                            },
    'recur_total_cap'    => { 'name' => 'Maximum overage charge for total'.
                                        ' ' . BS . 's (0 means no cap)',
                               'default' => 0,
                             },

    'global_cap'         => { 'name' => 'Global cap on all overage charges'.
                                        ' (0 means no cap)',
                              'default' => 0,
                            },

  },
  'fieldorder' => [qw( recur_included_hours recur_hourly_charge recur_hourly_cap recur_included_input recur_input_charge recur_input_cap recur_included_output recur_output_charge recur_output_cap recur_included_total recur_total_charge recur_total_cap global_cap )],
  'weight' => 40,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info(@_);
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
              / BU;

  my $output = $cust_pkg->attribute_since_sqlradacct( $last_bill,
                                                      $$sdate,
                                                      'AcctOutputOctets' )
               / BU;

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

  if ( $self->option('recur_total_charge') > 0 ) {
    push @$details,
      sprintf( "Last month's data %.3f %ss: %s", $total, BA, $totalcharge );
  }
  if ( $self->option('recur_input_charge') > 0 ) {
    push @$details,
      sprintf( "Last month's download %.3f %ss: %s", $input, BA, $inputcharge );
  }
  if ( $self->option('recur_output_charge') > 0 ) {
    push @$details,
      sprintf( "Last month's upload %.3f %ss: %s", $output, BA, $outputcharge );
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
