package FS::part_pkg::flat_introrate;

use strict;
use vars qw(@ISA %info $DEBUG $DEBUG_PRE);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

use Date::Manip qw(DateCalc UnixDate ParseDate);

@ISA = qw(FS::part_pkg::flat);
$DEBUG = 0;
$DEBUG_PRE = '[' . __PACKAGE__ . ']: ';

%info = (
  'name' => 'Introductory price for X months, then flat rate,'.
            'relative to setup date (anniversary billing)',
  'fields' =>  {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'intro_fee' => { 'name' => 'Introductory recurring free for this package',
                     'default' => 0,
                   },
    'intro_duration' => { 'name' => 'Duration of the introductory period, ' .
                                    'in number of months',
                          'default' => 0,
			},
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                    },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'setup_fee', 'intro_duration', 'intro_fee', 'recur_fee', 'unused_credit' ],
  'weight' => 150,
);

sub calc_recur {
  my($self, $cust_pkg, $time ) = @_;

  my ($duration) = ($self->option('intro_duration') =~ /^(\d+)$/);
  unless ($duration) {
    die "Invalid intro_duration: " . $self->option('intro_duration');
  }

  my $setup = &ParseDate('epoch ' . $cust_pkg->getfield('setup'));
  my $intro_end = &DateCalc($setup, "+${duration} month");
  my $recur;

  warn $DEBUG_PRE . "\$duration = ${duration}" if $DEBUG;
  warn $DEBUG_PRE . "\$intro_end = ${intro_end}" if $DEBUG;
  warn $DEBUG_PRE . "$$time < " . &UnixDate($intro_end, '%s') if $DEBUG;

  if ($$time < &UnixDate($intro_end, '%s')) {
    $recur = $self->option('intro_fee');
  } else {
    $recur = $self->option('recur_fee');
  }

  $recur;

}


1;
