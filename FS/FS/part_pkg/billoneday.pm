package FS::part_pkg::billoneday;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'charge a full month  every (selectable) billing day',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
			   },
    'cutoff_day' => { 'name' => 'billing day',
                      'default' => 1,
                    },

  },
  'fieldorder' => [ 'setup_fee', 'recur_fee','cutoff_day'],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '\'my $mnow = $sdate; my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($sdate) )[0,1,2,3,4,5]; $sdate = timelocal(0,0,0,$self->option('cutoff_day'),$mon,$year); \' + what.recur_fee.value',
  'freq' => 'm',
  'weight' => 30,
);

sub calc_recur {
  my($self, $cust_pkg, $sdate ) = @_;

  my $mnow = $$sdate;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($mnow) )[0,1,2,3,4,5];
  my $mstart = timelocal(0,0,0,$self->option('cutoff_day'),$mon,$year);
  my $mend = timelocal(0,0,0,$self->option('cutoff_day'), $mon == 11 ? 0 : $mon+1, $year+($mon==11));

  if($mday > $self->option('cutoff_date') and $mstart != $mnow ) {
    $$sdate = timelocal(0,0,0,$self->option('cutoff_day'), $mon == 11 ? 0 : $mon+1,  $year+($mon==11));
  }
  else{
    $$sdate = timelocal(0,0,0,$self->option('cutoff_day'), $mon, $year);
  }
  $self->option('recur_fee');
}
1;
