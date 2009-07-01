package FS::part_pkg::cdr_termination;

use strict;
use base qw( FS::part_pkg::recur_Common );
use vars qw( $DEBUG %info );
use Tie::IxHash;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

%info = (
  'name' => 'VoIP rating of CDR records for termination partners.',
  'shortname' => 'VoIP/telco CDR termination',
  'fields' => {

    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Base recurring fee for this package',
                         'default' => 0,
                       },

    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
                           },

    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },

    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },

    'recur_method'  => { 'name' => 'Recurring fee method',
                         #'type' => 'radio',
                         #'options' => \%recur_method,
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },
  },

  'fieldorder' => [qw(
                       setup_fee recur_fee recur_temporality unused_credit
                       recur_method cutoff_day
                     )
                  ],

  'weight' => 48,

);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->option('recur_temporality', 1) eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $charges = 0;

  # termination calculations

  # find CDRs with cdr_termination.status NULL
  #  and matching our customer via svc_external.id/title?  (and via what field?)

  #for each cdr, set status and rated price and add the charges, and add a line
  #to the invoice

  # eotermiation calculation

  $charges += $self->calc_recur_Common(@_);

  $charges;
}

sub is_free {
  0;
}

1;
