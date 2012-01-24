package FS::part_pkg::flat;
use base qw( FS::part_pkg::prorate_Mixin
             FS::part_pkg::discount_Mixin
             FS::part_pkg
           );

use strict;
use vars qw( %info %usage_recharge_fields @usage_recharge_fieldorder );
use Tie::IxHash;
use List::Util qw( min );
use FS::UI::bytecount;
use FS::Conf;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

tie my %contract_years, 'Tie::IxHash', (
  '' => '(none)',
  map { $_*12 => $_ } (1..5),
);

%info = (
  'name' => 'Flat rate (anniversary billing)',
  'shortname' => 'Anniversary',
  'inherit_fields' => [ 'prorate_Mixin', 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    #false laziness w/voip_cdr.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },

    #used in cust_pkg.pm so could add to any price plan
    'expire_months' => { 'name' => 'Auto-add an expiration date this number of months out',
                       },
    'adjourn_months'=> { 'name' => 'Auto-add a suspension date this number of months out',
                       },
    'contract_end_months'=> { 
                        'name' => 'Auto-add a contract end date this number of years out',
                        'type' => 'select',
                        'select_options' => \%contract_years,
                      },
    #used in cust_pkg.pm so could add to any price plan where it made sense
    'start_1st'     => { 'name' => 'Auto-add a start date to the 1st, ignoring the current month.',
                         'type' => 'checkbox',
                       },
    'sync_bill_date' => { 'name' => 'Prorate first month to synchronize '.
                                    'with the customer\'s other packages',
                          'type' => 'checkbox',
                        },
    'prorate_defer_bill' => { 
                          'name' => 'When synchronizing, defer the bill until '.
                                    'the customer\'s next bill date',
                          'type' => 'checkbox',
                        },
    'prorate_round_day' => {
                          'name' => 'When synchronizing, round the prorated '.
                                    'period to the nearest full day',
                          'type' => 'checkbox',
                        },
    'add_full_period' => { 'disabled' => 1 }, # doesn't make sense with sync?

    'suspend_bill' => { 'name' => 'Continue recurring billing while suspended',
                        'type' => 'checkbox',
                      },
    'unsuspend_adjust_bill' => 
                        { 'name' => 'Adjust next bill date forward when '.
                                    'unsuspending',
                          'type' => 'checkbox',
                        },
    'bill_recur_on_cancel' => {
                        'name' => 'Bill the last period on cancellation',
                        'type' => 'checkbox',
                        },
    'bill_suspend_as_cancel' => {
                        'name' => 'Bill immediately upon suspension', #desc?
                        'type' => 'checkbox',
                        },
    'externalid' => { 'name'   => 'Optional External ID',
                      'default' => '',
                    },
  },
  'fieldorder' => [ qw( recur_temporality 
                        expire_months adjourn_months
                        contract_end_months
                        start_1st
                        sync_bill_date prorate_defer_bill prorate_round_day
                        suspend_bill unsuspend_adjust_bill
                        bill_recur_on_cancel
                        bill_suspend_as_cancel
                        externalid ),
                  ],
  'weight' => 10,
);

sub price_info {
    my $self = shift;
    my $conf = new FS::Conf;
    my $money_char = $conf->config('money_char') || '$';
    my $setup = $self->option('setup_fee') || 0;
    my $recur = $self->option('recur_fee', 1) || 0;
    my $str = '';
    $str = $money_char . $setup . ($recur ? ' setup ' : ' one-time') if $setup;
    $str .= ', ' if ($setup && $recur);
    $str .= $money_char. $recur. '/'. $self->freq_pretty if $recur;
    $str;
}

sub calc_setup {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;

  return 0 if $self->prorate_setup($cust_pkg, $sdate);

  my $i = 0;
  my $count = $self->option( 'additional_count', 'quiet' ) || 0;
  while ($i < $count) {
    push @$details, $self->option( 'additional_info' . $i++ );
  }

  my $quantity = $cust_pkg->quantity || 1;

  my $charge = $quantity * $self->unit_setup($cust_pkg, $sdate, $details);

  my $discount = 0;
  if ( $charge > 0 ) {
      $param->{'setup_charge'} = $charge;
      $discount = $self->calc_discount($cust_pkg, $sdate, $details, $param);
      delete $param->{'setup_charge'};
  }

  sprintf('%.2f', $charge - $discount);
}

sub unit_setup {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  $self->option('setup_fee') || 0;
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding' && !$last_bill;

  my $charge = $self->base_recur($cust_pkg, $sdate);
  if ( my $cutoff_day = $self->cutoff_day($cust_pkg) ) {
    $charge = $self->calc_prorate(@_, $cutoff_day);
  }
  elsif ( $param->{freq_override} ) {
    # XXX not sure if this should be mutually exclusive with sync_bill_date.
    # Given the very specific problem that freq_override is meant to 'solve',
    # it probably should.
    $charge *= $param->{freq_override} if $param->{freq_override};
  }

  my $discount = $self->calc_discount($cust_pkg, $sdate, $details, $param);
  return sprintf('%.2f', $charge - $discount);
}

sub cutoff_day {
  my $self = shift;
  my $cust_pkg = shift;
  if ( $self->option('sync_bill_date',1) ) {
    my $next_bill = $cust_pkg->cust_main->next_bill_date;
    if ( defined($next_bill) ) {
      return (localtime($next_bill))[3];
    }
  }
  return 0;
}

sub base_recur {
  my($self, $cust_pkg, $sdate) = @_;
  $self->option('recur_fee', 1) || 0;
}

sub base_recur_permonth {
  my($self, $cust_pkg) = @_;

  return 0 unless $self->freq =~ /^\d+$/ && $self->freq > 0;

  sprintf('%.2f', $self->base_recur($cust_pkg) / $self->freq );
}

sub calc_remain {
  my ($self, $cust_pkg, %options) = @_;

  my $time;
  if ($options{'time'}) {
    $time = $options{'time'};
  } else {
    $time = time;
  }

  my $next_bill = $cust_pkg->getfield('bill') || 0;

  return 0 if    ! $self->base_recur($cust_pkg, \$time)
              || ! $next_bill
              || $next_bill < $time;

  my %sec = (
    'h' =>    3600, # 60 * 60
    'd' =>   86400, # 60 * 60 * 24
    'w' =>  604800, # 60 * 60 * 24 * 7
    'm' => 2629744, # 60 * 60 * 24 * 365.2422 / 12 
  );

  $self->freq =~ /^(\d+)([hdwm]?)$/
    or die 'unparsable frequency: '. $self->freq;
  my $freq_sec = $1 * $sec{$2||'m'};
  return 0 unless $freq_sec;

  sprintf("%.2f", $self->base_recur($cust_pkg, \$time) * ( $next_bill - $time ) / $freq_sec );

}

sub is_free_options {
  qw( setup_fee recur_fee );
}

sub is_prepaid { 0; } #no, we're postpaid

sub can_start_date { ! shift->option('start_1st', 1) }

sub can_discount { 1; }

sub recur_temporality {
  my $self = shift;
  $self->option('recur_temporality', 1);
}

sub usage_valuehash {
  my $self = shift;
  map { $_, $self->option($_) }
    grep { $self->option($_, 'hush') } 
    qw(seconds upbytes downbytes totalbytes);
}

sub reset_usage {
  my($self, $cust_pkg, %opt) = @_;
  warn "   resetting usage counters" if defined($opt{debug}) && $opt{debug} > 1;
  my %values = $self->usage_valuehash;
  if ($self->option('usage_rollover', 1)) {
    $cust_pkg->recharge(\%values);
  }else{
    $cust_pkg->set_usage(\%values, %opt);
  }
}

1;
