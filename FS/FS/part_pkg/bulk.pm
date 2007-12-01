package FS::part_pkg::bulk;

use strict;
use vars qw(@ISA %info);
use Date::Format;
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Bulk billing based on number of active services',
  'fields' => {
    'setup_fee' => { 'name'    => 'Setup fee for the entire bulk package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name'    => 'Recurring fee for the entire bulk package',
                     'default' => 0,
                   },
    'svc_setup_fee' => { 'name'    => 'Setup fee for each new service',
                         'default' => 0,
                       },
    'svc_recur_fee' => { 'name'    => 'Recurring fee for each service',
                         'default' => 0,
                       },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'svc_setup_fee', 'svc_recur_fee',
                    'unused_credit', ],
  'weight' => 55,
);

sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';
  
  my $svc_setup_fee = $self->option('svc_setup_fee');

  my $last_bill = $cust_pkg->last_bill;

  my $total_svc_charge = 0;

                                           #   END      START
  foreach my $h_svc ( $cust_pkg->h_cust_svc( $$sdate, $last_bill ) ) {

    my $svc_charge = 0;
    my $svc_details = $h_svc->label. ': ';

    my $svc_start = $h_svc->date_inserted;
    if ( $svc_start < $last_bill ) {
      $svc_start = $last_bill;
    } elsif ( $svc_setup_fee ) {
      $svc_charge += $svc_setup_fee;
      $details .= $money_char. sprintf('%.2f setup, ', $svc_setup_fee);
    }

    my $svc_end = $h_svc->date_deleted;
    $svc_end = ( !$svc_end || $svc_end > $$sdate ) ? $$sdate : $svc_end;

    $svc_charge = $self->option('svc_recur_fee') * ( $svc_end - $svc_start )
                                                 / ( $$sdate  - $last_bill );

    $details .= $money_char. sprintf('%.2f', $svc_charge ).
                ' ('.  time2str('%x', $svc_start).
                ' - '. time2str('%x', $svc_end  ). ')'
    if $self->option('svc_recur_fee');

    push @$details, $details;
    $total_svc_charge += $svc_charge;

  }

  sprintf("%.2f", $self->base_recur($cust_pkg) + $total_svc_charge );
}

sub is_free_options {
  qw( setup_fee recur_fee svc_setup_fee svc_recur_fee );
}

