package FS::part_event::Action::fee;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Late fee (flat)'; }

sub event_stage { 'pre-bill'; }

sub option_fields {
  ( 
    'charge'   => { label=>'Amount', type=>'money', }, # size=>7, },
    'reason'   => 'Reason (invoice line item)',
    'classnum' => { label=>'Package class' => type=>'select-pkg_class', },
    'taxclass' => { label=>'Tax class', type=>'select-taxclass', },
    'setuptax' => { label=>'Late fee is tax exempt',
                    type=>'checkbox', value=>'Y' },
    'nextbill' => { label=>'Hold late fee until next invoice',
                    type=>'checkbox', value=>'Y' },
  );
}

sub default_weight { 10; }

sub _calc_fee {
  #my( $self, $cust_object ) = @_;
  my $self = shift;
  $self->option('charge');
}

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $conf = new FS::Conf;

  my %charge = (
    'amount'   => $self->_calc_fee($cust_object),
    'pkg'      => $self->option('reason'),
    'taxclass' => $self->option('taxclass'),
    'classnum' => ( $self->option('classnum')
                      || scalar($conf->config('finance_pkgclass')) ),
    'setuptax' => $self->option('setuptax'),
  );

  #unless its more than N months away?
  $charge{'start_date'} = $cust_main->next_bill_date
    if $self->option('nextbill');

  my $error = $cust_main->charge( \%charge );

  die $error if $error;

  '';
}

1;
