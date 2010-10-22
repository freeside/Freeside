package FS::part_pkg::flat;

use strict;
use vars qw( @ISA %info
             %usage_fields %usage_recharge_fields
             @usage_fieldorder @usage_recharge_fieldorder
           );
use Tie::IxHash;
use List::Util qw(min); # max);
#use FS::Record qw(qsearch);
use FS::UI::bytecount;
use FS::Conf;
use FS::part_pkg;
use FS::cust_bill_pkg_discount;

@ISA = qw(FS::part_pkg FS::part_pkg::prorate_Mixin);

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

tie my %contract_years, 'Tie::IxHash', (
  '' => '(none)',
  map { $_*12 => $_ } (1..5),
);

%usage_fields = (

    'seconds'       => { 'name' => 'Time limit for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                       },
    'upbytes'       => { 'name' => 'Upload limit for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'downbytes'     => { 'name' => 'Download limit for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'totalbytes'    => { 'name' => 'Transfer limit for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
);

%usage_recharge_fields = (

    'recharge_amount'       => { 'name' => 'Cost of recharge for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*(\.\d{2})?$/ },
                       },
    'recharge_seconds'      => { 'name' => 'Recharge time for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                       },
    'recharge_upbytes'      => { 'name' => 'Recharge upload for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'recharge_downbytes'    => { 'name' => 'Recharge download for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'recharge_totalbytes'   => { 'name' => 'Recharge transfer for this package',
                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
                         'format' => \&FS::UI::bytecount::display_bytecount,
                         'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'usage_rollover' => { 'name' => 'Allow usage from previous period to roll '.
                                    ' over into current period',
                          'type' => 'checkbox',
                        },
    'recharge_reset' => { 'name' => 'Reset usage to these values on manual '.
                                    'package recharge',
                          'type' => 'checkbox',
                        },
);

@usage_fieldorder = qw( seconds upbytes downbytes totalbytes );
@usage_recharge_fieldorder = qw(
  recharge_amount recharge_seconds recharge_upbytes
  recharge_downbytes recharge_totalbytes
  usage_rollover recharge_reset
);

%info = (
  'name' => 'Flat rate (anniversary billing)',
  'shortname' => 'Anniversary',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Recurring fee for this package',
                         'default' => 0,
                       },

    #false laziness w/voip_cdr.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
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
    'suspend_bill' => { 'name' => 'Continue recurring billing while suspended',
                        'type' => 'checkbox',
                      },
    'unsuspend_adjust_bill' => 
                        { 'name' => 'Adjust next bill date forward when '.
                                    'unsuspending',
                          'type' => 'checkbox',
                        },

    %usage_fields,
    %usage_recharge_fields,

    'externalid' => { 'name'   => 'Optional External ID',
                      'default' => '',
                    },
  },
  'fieldorder' => [ qw( setup_fee recur_fee
                        recur_temporality unused_credit
                        expire_months adjourn_months
                        contract_end_months
                        start_1st sync_bill_date
                        suspend_bill unsuspend_adjust_bill
                      ),
                    @usage_fieldorder, @usage_recharge_fieldorder,
                    qw( externalid ),
                  ],
  'weight' => 10,
);

sub calc_setup {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $i = 0;
  my $count = $self->option( 'additional_count', 'quiet' ) || 0;
  while ($i < $count) {
    push @$details, $self->option( 'additional_info' . $i++ );
  }

  my $quantity = $cust_pkg->quantity || 1;

  sprintf("%.2f", $quantity * $self->unit_setup($cust_pkg, $sdate, $details) );
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
    if $self->option('recur_temporality', 1) eq 'preceding' && $last_bill == 0;

  if( $self->option('sync_bill_date',1) ) {
    return $self->calc_prorate(@_);
  }
  else {
    my $charge = $self->base_recur($cust_pkg);
    $charge *= $param->{freq_override} if $param->{freq_override};
    my $discount = $self->calc_discount($cust_pkg, $sdate, $details, $param);

    return sprintf('%.2f', $charge - $discount);
  }
}

sub calc_discount {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;

  my $br = $self->base_recur($cust_pkg);

  my $tot_discount = 0;
  #UI enforces just 1 for now, will need ordering when they can be stacked

  if ( $param->{freq_override} ) {
    my $real_part_pkg = new FS::part_pkg { $self->hash };
    $real_part_pkg->pkgpart($param->{real_pkgpart} || $self->pkgpart);
    my @discount = grep { $_->months == $param->{freq_override} }
                   map { $_->discount }
                   $real_part_pkg->part_pkg_discount;
    my $discount = shift @discount;
    $param->{months} = $param->{freq_override} unless $param->{months};
    my $error;
    if ($discount) {
      if ($discount->months == $param->{months}) {
        $cust_pkg->discountnum($discount->discountnum);
        $error = $cust_pkg->insert_discount;
      } else {
        $cust_pkg->discountnum(-1);
        foreach ( qw( amount percent months ) ) {
          my $method = "discountnum_$_";
          $cust_pkg->$method($discount->$_);
        }
        $error = $cust_pkg->insert_discount;
      }
      die "error discounting using part_pkg_discount: $error" if $error;
    }
  }

  my @cust_pkg_discount = $cust_pkg->cust_pkg_discount_active;
  foreach my $cust_pkg_discount ( @cust_pkg_discount ) {
     my $discount = $cust_pkg_discount->discount;
     #UI enforces one or the other (for now?  probably for good)
     my $amount = 0;
     $amount += $discount->amount
       if $cust_pkg->pkgpart == $param->{real_pkgpart};
     $amount += sprintf('%.2f', $discount->percent * $br / 100 );

     my $chg_months = $param->{'months'} || $cust_pkg->part_pkg->freq;
     
     my $months = $discount->months
                    ? min( $chg_months,
                           $discount->months - $cust_pkg_discount->months_used )
                    : $chg_months;

     my $error = $cust_pkg_discount->increment_months_used($months)
       if $cust_pkg->pkgpart == $param->{real_pkgpart};
     die "error discounting: $error" if $error;

     $amount *= $months;
     $amount = sprintf('%.2f', $amount);

     next unless $amount > 0;

     #record details in cust_bill_pkg_discount
     my $cust_bill_pkg_discount = new FS::cust_bill_pkg_discount {
       'pkgdiscountnum' => $cust_pkg_discount->pkgdiscountnum,
       'amount'         => $amount,
       'months'         => $months,
     };
     push @{ $param->{'discounts'} }, $cust_bill_pkg_discount;

     #add details on discount to invoice
     my $conf = new FS::Conf;
     my $money_char = $conf->config('money_char') || '$';  
     $months = sprintf('%.2f', $months) if $months =~ /\./;

     my $d = 'Includes ';
     $d .= $discount->name. ' ' if $discount->name;
     $d .= 'discount of '. $discount->description_short;
     $d .= " for $months month". ( $months!=1 ? 's' : '' );
     $d .= ": $money_char$amount" if $months != 1 || $discount->percent;
     push @$details, $d;

     $tot_discount += $amount;
  }

  sprintf('%.2f', $tot_discount);
}

sub base_recur {
  my($self, $cust_pkg) = @_;
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

  #my $last_bill = $cust_pkg->last_bill || 0;
  my $last_bill = $cust_pkg->get('last_bill') || 0; #->last_bill falls back to setup

  return 0 if    ! $self->base_recur($cust_pkg)
              || ! $self->option('unused_credit', 1)
              || ! $last_bill
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

  sprintf("%.2f", $self->base_recur($cust_pkg) * ( $next_bill - $time ) / $freq_sec );

}

sub is_free_options {
  qw( setup_fee recur_fee );
}

sub is_prepaid { 0; } #no, we're postpaid

#XXX discounts only on recurring fees for now (no setup/one-time or usage)
sub can_discount {
  my $self = shift;
  $self->freq =~ /^\d+$/ && $self->freq > 0;
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
