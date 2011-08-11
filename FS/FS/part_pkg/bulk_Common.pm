package FS::part_pkg::bulk_Common;
use base qw( FS::part_pkg::flat );

use strict;
use vars qw($DEBUG $me %info);
use Date::Format;
use FS::Conf;

$DEBUG = 0;
$me = '[FS::part_pkg::bulk_Common]';

%info = (
  'disabled' => 1,
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'svc_setup_fee' => { 'name'    => 'Setup fee for each new service',
                         'default' => 0,
                       },
    'svc_recur_fee' => { 'name'    => 'Recurring fee for each service',
                         'default' => 0,
                       },
    'summarize_svcs'=> { 'name' => 'Show a count of services on the invoice, '.
                                   'instead of a detailed list',
                         'type' => 'checkbox',
                       },
    'no_prorate'    => { 'name' => 'Don\'t prorate recurring fees on services '.
                                   'active for a partial month',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'svc_setup_fee', 'svc_recur_fee',
                    'summarize_svcs', 'no_prorate' ],
  'weight' => 51,
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    my $svc_setup_fee = $self->option('svc_setup_fee');
    my $svc_recur_fee = $self->option('svc_recur_fee');
    my $conf = new FS::Conf;
    my $money_char = $conf->config('money_char') || '$';
    $str .= " , bulk" if $str;
    $str .= ": $money_char" . $svc_setup_fee . " one-time per service" 
	if $svc_setup_fee;
    $str .= ", " if ($svc_setup_fee && $svc_recur_fee);
    $str .= $money_char . $svc_recur_fee . " recurring per service"
	if $svc_recur_fee;
    $str;
}

#some false laziness-ish w/agent.pm...  not a lot
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';
  
  my $last_bill = $cust_pkg->last_bill;

  my $total_svc_charge = 0;
  my %n_setup = ();
  my %n_recur = ();
  my %part_svc_label = ();

  my $summarize = $self->option('summarize_svcs',1);

  foreach my $cust_svc ( $self->_bulk_cust_svc( $cust_pkg, $sdate ) ) {

    my @label = $cust_svc->label_long( $$sdate, $last_bill );
    die "fatal: no label found, wtf?" unless scalar(@label); #?
    my $svc_details = $label[0]. ': '. $label[1]. ': ';
    $part_svc_label{$cust_svc->svcpart} ||= $label[0];

    my $svc_charge = 0;

    my $setup = $self->_bulk_setup($cust_pkg, $cust_svc);
    if ( $setup ) {
      $svc_charge += $setup;
      $svc_details .= $money_char. sprintf('%.2f setup, ', $setup);
      $n_setup{$cust_svc->svcpart}++;
    }

    my( $recur, $r_details ) = $self->_bulk_recur($cust_pkg, $cust_svc, $sdate);
    if ( $recur ) {
      $svc_charge += $recur;
      $svc_details .= $money_char. sprintf('%.2f', $recur). $r_details;
      $n_recur{$cust_svc->svcpart}++;
      push @$details, $svc_details if !$summarize;
    }

    $total_svc_charge += $svc_charge;

  }

  if ( $summarize ) {
    foreach my $svcpart (keys %part_svc_label) {
      push @$details, sprintf('Setup fee: %d @ '.$money_char.'%.2f',
        $n_setup{$svcpart}, $self->option('svc_setup_fee') )
        if $self->option('svc_setup_fee') and $n_setup{$svcpart};
      push @$details, sprintf('%d services @ '.$money_char.'%.2f',
        $n_recur{$svcpart}, $self->option('svc_recur_fee') )
        if $n_recur{$svcpart};
    }
  }

  sprintf('%.2f', $self->base_recur($cust_pkg, $sdate) + $total_svc_charge );
}

sub can_discount { 0; }

sub hide_svc_detail { 1; }

sub is_free_options {
  qw( setup_fee recur_fee svc_setup_fee svc_recur_fee );
}

1;

