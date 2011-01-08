package FS::part_pkg::subscription;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'First partial month full charge, then flat-rate (selectable billing day)',
  'shortname' => 'Subscription (Nth of month, full charge for first)',
  'inherit_fields' => [ 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'cutoff_day' => { 'name' => 'Billing day',
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
  'fieldorder' => [ 'cutoff_day', 'seconds',
                    'upbytes', 'downbytes', 'totalbytes',
                    'recharge_amount', 'recharge_seconds', 'recharge_upbytes',
                    'recharge_downbytes', 'recharge_totalbytes',
                    'usage_rollover', 'recharge_reset', 'externalid' ],
  'freq' => 'm',
  'weight' => 30,
);

sub calc_recur {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;
  my $cutoff_day = $self->option('cutoff_day', 1) || 1;
  my $mnow = $$sdate;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($mnow) )[0,1,2,3,4,5];

  if ( $mday < $cutoff_day ) {
     if ($mon==0) {$mon=11;$year--;}
     else {$mon--;}
  }

  $$sdate = timelocal(0,0,0,$cutoff_day,$mon,$year);

  my $br = $self->base_recur($cust_pkg, $sdate);

  my $discount = $self->calc_discount($cust_pkg, $sdate, $details, $param);

  sprintf('%.2f', $br - $discount);
}

1;
