package FS::part_pkg::bulk;
use base qw( FS::part_pkg::bulk_Common );

use strict;
use vars qw($DEBUG $me %info);
use Date::Format;
use FS::Conf;
use FS::cust_svc_option;

$DEBUG = 0;
$me = '[FS::part_pkg::bulk]';

%info = (
  'name' => 'Bulk billing based on number of active services (at invoice generation)',
  'inherit_fields' => [ 'bulk_Common', 'global_Mixin' ],
  'weight' => 50,
);

#some false laziness-ish w/agent.pm...  not a lot
# more w/bulk.pm's calc_recur
sub calc_recur {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';
  
  my $svc_setup_fee = $self->option('svc_setup_fee');

  my $total_svc_charge = 0;
  my %n_setup = ();
  my %n_recur = ();
  my %part_svc_label = ();

  my $summarize = $self->option('summarize_svcs',1);

  foreach my $cust_svc ( $cust_pkg->cust_svc ) {

    my @label = $cust_svc->label_long;
    #die "fatal: no historical label found, wtf?" unless scalar(@label); #?
    my $svc_details = $label[0]. ': '. $label[1]. ': ';
    $part_svc_label{$h_cust_svc->svcpart} ||= $label[0];

    my $svc_charge = 0;

    if ( $svc_setup_fee && ! $cust_svc->option('bulk_setup') ) {

      my $bulk_setup = new FS::cust_svc_option {
        'svcnum'      => $cust_svc->svcnum,
        'optionname'  => 'bulk_setup',
        'optionvalue' => time, #invoice date?
      };
      my $error = $bulk_setup->insert;
      die $error if $error;

      $svc_charge += $svc_setup_fee;
      $svc_details .= $money_char. sprintf('%.2f setup, ', $svc_setup_fee);
      $n_setup{$cust_svc->svcpart}++;
    }

    my $recur_charge = $self->option('svc_recur_fee');
    $svc_details .= $money_char. sprintf('%.2f', $recur_charge );

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

  sprintf('%.2f', $self->base_recur($cust_pkg, $sdate) + $total_svc_charge );
}

sub can_discount { 0; }

sub hide_svc_detail {
  1;
}

sub is_free_options {
  qw( setup_fee recur_fee svc_setup_fee svc_recur_fee );
}

1;

