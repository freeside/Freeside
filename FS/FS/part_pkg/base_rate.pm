package FS::part_pkg::base_rate;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch);
use FS::part_pkg;

@ISA = qw(FS::part_pkg);

%info = (
  'name' => 'Base rate (anniversary billing, Times units ordered)',
            # XXX it multiplies recurring fee by cust_pkg option "units", how to
            # express that
  'shortname' => 'Bulk (manual from "units" option)',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Recurring Base fee for this package',
                         'default' => 0,
                       },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'externalid' => { 'name'   => 'Optional External ID',
                      'default' => '',
                    },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit', 
                    'externalid' ],
  'weight' => 52,
);

sub calc_setup {
  my($self, $cust_pkg, $sdate, $details ) = @_;

  my $i = 0;
  my $count = $self->option( 'additional_count', 'quiet' ) || 0;
  while ($i < $count) {
    push @$details, $self->option( 'additional_info' . $i++ );
  }

  $self->option('setup_fee');
}

sub calc_recur {
  my($self, $cust_pkg) = @_;
  $self->base_recur($cust_pkg);
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  my $units = $cust_pkg->option('units') ? $cust_pkg->option('units') : 1 ;
  	# default to 1 if not found
  sprintf("%.2f", 
	  ($self->option('recur_fee') * $units ) 
  );
}

sub calc_remain {
  my ($self, $cust_pkg) = @_;
  my $time = time;  #should be able to pass this in for credit calculation
  my $next_bill = $cust_pkg->getfield('bill') || 0;
  my $last_bill = $cust_pkg->last_bill || 0;
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

sub is_prepaid {
  0; #no, we're postpaid
}

1;
