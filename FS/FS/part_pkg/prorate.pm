package FS::part_pkg::prorate;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;

@ISA = qw(FS::part_pkg);

%info = (
    'name' => 'First partial month pro-rated, then flat-rate (1st of month billing)',
    'fields' =>  {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee' ],
    #'setup' => 'what.setup_fee.value',
    #'recur' => '\'my $mnow = $sdate; my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($sdate) )[0,1,2,3,4,5]; my $mstart = timelocal(0,0,0,1,$mon,$year); my $mend = timelocal(0,0,0,1, $mon == 11 ? 0 : $mon+1, $year+($mon==11)); $sdate = $mstart; ( $part_pkg->freq - 1 ) * \' + what.recur_fee.value + \' / $part_pkg->freq + \' + what.recur_fee.value + \' / $part_pkg->freq * ($mend-$mnow) / ($mend-$mstart) ; \'',
    'freq' => 'm',
    'weight' => 20,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my($self, $cust_pkg, $sdate ) = @_;
  my $mnow = $$sdate;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($mnow) )[0,1,2,3,4,5];
  my $mstart = timelocal(0,0,0,1,$mon,$year);
  my $mend = timelocal(0,0,0,1, $mon == 11 ? 0 : $mon+1, $year+($mon==11));
  $$sdate = $mstart;

  my $permonth = $self->option('recur_fee') / $self->freq;

  $permonth * ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );
}

1;
