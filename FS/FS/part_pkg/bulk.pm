package FS::part_pkg::bulk;

use strict;
use vars qw(@ISA $DEBUG $me %info);
use Date::Format;
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

$DEBUG = 0;
$me = '[FS::part_pkg::bulk]';

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
    'summarize_svcs'=> { 'name' => 'Show a count of services on the invoice, '.
                                   'instead of a detailed list',
                         'type' => 'checkbox',
                       },
    'no_prorate'    => { 'name' => 'Don\'t prorate recurring fees on new '.
                                   'services',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'svc_setup_fee', 'svc_recur_fee',
                    'unused_credit', 'summarize_svcs', 'no_prorate' ],
  'weight' => 50,
);

#some false laziness-ish w/agent.pm...  not a lot
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';
  
  my $svc_setup_fee = $self->option('svc_setup_fee');

  my $last_bill = $cust_pkg->last_bill;

  return sprintf("%.2f", $self->base_recur($cust_pkg) )
    unless $$sdate > $last_bill;

  my $total_svc_charge = 0;
  my %n_setup = ();
  my %n_recur = ();
  my %part_svc_label = ();

  my $summarize = $self->option('summarize_svcs',1);

  warn "$me billing for bulk services from ". time2str('%x', $last_bill).
                                      " to ". time2str('%x', $$sdate). "\n"
    if $DEBUG;

                                           #   END      START
  foreach my $h_cust_svc ( $cust_pkg->h_cust_svc( $$sdate, $last_bill ) ) {

    my @label = $h_cust_svc->label_long( $$sdate, $last_bill );
    die "fatal: no historical label found, wtf?" unless scalar(@label); #?
    my $svc_details = $label[0]. ': '. $label[1]. ': ';
    $part_svc_label{$h_cust_svc->svcpart} ||= $label[0];

    my $svc_charge = 0;

    my $svc_start = $h_cust_svc->date_inserted;
    if ( $svc_start < $last_bill ) {
      $svc_start = $last_bill;
    } elsif ( $svc_setup_fee ) {
      $svc_charge += $svc_setup_fee;
      $svc_details .= $money_char. sprintf('%.2f setup, ', $svc_setup_fee);
      $n_setup{$h_cust_svc->svcpart}++;
    }

    my $svc_end = $h_cust_svc->date_deleted;
    $svc_end = ( !$svc_end || $svc_end > $$sdate ) ? $$sdate : $svc_end;

    my $recur_charge;
    if ( $self->option('no_prorate',1) ) {
      $recur_charge = $self->option('svc_recur_fee');
    }
    else {
      $recur_charge = $self->option('svc_recur_fee') 
                                     * ( $svc_end - $svc_start )
                                     / ( $$sdate  - $last_bill );
    }

    $svc_details .= $money_char. sprintf('%.2f', $recur_charge ).
                    ' ('.  time2str('%x', $svc_start).
                    ' - '. time2str('%x', $svc_end  ). ')'
      if $recur_charge;

    $svc_charge += $recur_charge;
    $n_recur{$h_cust_svc->svcpart}++;
    push @$details, $svc_details if !$summarize;
    $total_svc_charge += $svc_charge;

  }
  if ( $summarize ) {
    foreach my $svcpart (keys %part_svc_label) {
      push @$details, sprintf('Setup fee: %d @ '.$money_char.'%.2f',
        $n_setup{$svcpart}, $svc_setup_fee )
        if $svc_setup_fee and $n_setup{$svcpart};
      push @$details, sprintf('%d services @ '.$money_char.'%.2f',
        $n_recur{$svcpart}, $self->option('svc_recur_fee') )
        if $n_recur{$svcpart};
    }
  }

  sprintf('%.2f', $self->base_recur($cust_pkg) + $total_svc_charge );
}

sub can_discount { 0; }

sub hide_svc_detail {
  1;
}

sub is_free_options {
  qw( setup_fee recur_fee svc_setup_fee svc_recur_fee );
}

1;

