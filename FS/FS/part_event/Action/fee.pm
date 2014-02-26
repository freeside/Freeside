package FS::part_event::Action::fee;

# DEPRECATED; will most likely be removed in 4.x

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
    'limit_to_credit'=>
                  { label=>"Charge no more than the customer's credit balance",
                    type=>'checkbox', value=>'Y' },
  );
}

sub default_weight { 10; }

sub _calc_fee {
  my( $self, $cust_object ) = @_;
  if ( $self->option('limit_to_credit') ) {
    my $balance = $cust_object->cust_main->balance;
    if ( $balance >= 0 ) {
      return 0;
    } elsif ( (-1 * $balance) < $self->option('charge') ) {
      my $total = -1 * $balance;
      # if it's tax exempt, then we're done
      # XXX we also bail out if you're using external tax tables, because
      # they're definitely NOT linear and we haven't yet had a reason to 
      # make that case work.
      return $total if $self->option('setuptax') eq 'Y'
                    or FS::Conf->new->exists('enable_taxproducts');

      # estimate tax rate
      # false laziness with xmlhttp-calculate_taxes, cust_main::Billing, etc.
      # XXX not accurate with monthly exemptions
      my $cust_main = $cust_object->cust_main;
      my $taxlisthash = {};
      my $charge = FS::cust_bill_pkg->new({
          setup => $total,
          recur => 0,
          details => []
      });
      my $part_pkg = FS::part_pkg->new({
          taxclass => $self->option('taxclass')
      });
      my $error = $cust_main->_handle_taxes( $taxlisthash, $charge,
        location  => $cust_main->ship_location,
        part_item => $part_pkg,
      );
      if ( $error ) {
        warn "error estimating taxes for breakage charge: custnum ".$cust_main->custnum."\n";
        return $total;
      }
      # $taxlisthash: tax identifier => [ cust_main_county, cust_bill_pkg... ]
      my $total_rate = 0;
      my @taxes = map { $_->[0] } values %$taxlisthash;
      foreach (@taxes) {
        $total_rate += $_->tax;
      }
      return $total if $total_rate == 0; # no taxes apply

      my $total_cents = $total * 100;
      my $charge_cents = sprintf('%.0f', $total_cents * 100/(100 + $total_rate));
      return ($charge_cents / 100);
    }
  }

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

  # amazingly, FS::cust_main::charge will allow a charge of zero
  return '' if $charge{'amount'} == 0;

  #unless its more than N months away?
  $charge{'start_date'} = $cust_main->next_bill_date
    if $self->option('nextbill');

  my $error = $cust_main->charge( \%charge );

  die $error if $error;

  '';
}

1;
