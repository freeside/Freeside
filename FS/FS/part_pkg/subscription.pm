package FS::part_pkg::subscription;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;

@ISA = qw(FS::part_pkg::flat);

%info = (
    'name' => 'First partial month full charge, then flat-rate (1st of month billing)',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee' ],
    #'setup' => 'what.setup_fee.value',
    #'recur' => '\'my $mnow = $sdate; my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($sdate) )[0,1,2,3,4,5]; $sdate = timelocal(0,0,0,1,$mon,$year); \' + what.recur_fee.value',
    'freq' => 'm',
    'weight' => 30,
);

sub calc_recur {
  my($self, $cust_pkg, $sdate ) = @_;

  my $mnow = $$sdate;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($mnow) )[0,1,2,3,4,5];
  $$sdate = timelocal(0,0,0,1,$mon,$year);

  $self->option('recur_fee');
}

1;
