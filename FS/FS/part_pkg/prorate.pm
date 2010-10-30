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
    'add_full_period'=> { 'name' => 'When prorating first month, also bill '.
                                    'for one full period after that',
                          'type' => 'checkbox',
                        },
    'prorate_round_day'=> {
                          'name' => 'When prorating first month, round to '.
                                    'the nearest full day',
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
                    'usage_rollover', 'recharge_reset', 'add_full_period',
                    'prorate_round_day', 'externalid', ],
  'freq' => 'm',
  'weight' => 20,
);

sub calc_recur {
  my $self = shift;
  my $cutoff_day = $self->option('cutoff_day') || 1;
  return $self->calc_prorate(@_, $cutoff_day) - $self->calc_discount(@_);
}

1;
