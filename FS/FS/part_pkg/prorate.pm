package FS::part_pkg::prorate;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'First partial month pro-rated, then flat-rate (selectable billing day)',
  'shortname' => 'Prorate (Nth of month billing)',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                    },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'cutoff_day' => { 'name' => 'Billing Day (1 - 28)',
                      'default' => 1,
                    },
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
    'recharge_downbytes'    => { 'name' => 'Recharge download for this package',                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
			 'format' => \&FS::UI::bytecount::display_bytecount,
			 'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'recharge_totalbytes'   => { 'name' => 'Recharge transfer for this package',                         'default' => '',
                         'check' => sub { shift =~ /^\d*$/ },
			 'format' => \&FS::UI::bytecount::display_bytecount,
			 'parse' => \&FS::UI::bytecount::parse_bytecount,
                       },
    'usage_rollover' => { 'name' => 'Allow usage from previous period to roll '.
			            'over into current period',
			  'type' => 'checkbox',
                        },
    'recharge_reset' => { 'name' => 'Reset usage to these values on manual '.
                                    'package recharge',
                          'type' => 'checkbox',
                        },

    #it would be better if this had to be turned on, its confusing
    'externalid' => { 'name'   => 'Optional External ID',
                      'default' => '',
                    },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit', 'cutoff_day',
                    'seconds', 'upbytes', 'downbytes', 'totalbytes',
                    'recharge_amount', 'recharge_seconds', 'recharge_upbytes',
                    'recharge_downbytes', 'recharge_totalbytes',
                    'usage_rollover', 'recharge_reset', 'externalid', ],
  'freq' => 'm',
  'weight' => 20,
);

sub calc_recur {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;
  my $cutoff_day = $self->option('cutoff_day', 1) || 1;
  my $mnow = $$sdate;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($mnow) )[0,1,2,3,4,5];
  my $mend;
  my $mstart;
  
  if ( $mday >= $cutoff_day ) {
    $mend =
      timelocal(0,0,0,$cutoff_day, $mon == 11 ? 0 : $mon+1, $year+($mon==11));
    $mstart =
      timelocal(0,0,0,$cutoff_day,$mon,$year);  

  } else {
    $mend = timelocal(0,0,0,$cutoff_day, $mon, $year);
    if ($mon==0) {$mon=11;$year--;} else {$mon--;}
    $mstart=  timelocal(0,0,0,$cutoff_day,$mon,$year);  
  }

  $$sdate = $mstart;
  my $permonth = $self->option('recur_fee') / $self->freq;

  my $months = ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );

  $param->{'months'} = $months;
  my $discount = $self->calc_discount( $cust_pkg, $sdate, $details, $param);

  sprintf('%.2f', $permonth * $months - $discount);
}

1;
