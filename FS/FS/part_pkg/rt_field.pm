package FS::part_pkg::rt_field;

use strict;
use FS::Conf;
use FS::TicketSystem;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::recur_Common;
use FS::part_pkg::global_Mixin;
use FS::rt_field_charge;

our @ISA = qw(FS::part_pkg::recur_Common);

our $DEBUG = 0;

use vars qw( $conf $money_char );

FS::UID->install_callback( sub {
  $conf = new FS::Conf;
  $money_char = $conf->config('money_char') || '$';
});

my %custom_field = (
  'type'        => 'select-rt-customfield',
  'lookuptype'  => 'RT::Queue-RT::Ticket',
);

my %multiple = (
  'multiple' => 1,
  'parse' => sub { @_ }, # because /edit/process/part_pkg.pm doesn't grok select multiple
);

our %info = (
  'name'      =>  'Bill from custom fields in resolved RT tickets',
  'shortname' =>  'RT custom rate',
  'weight'    => 65,
  'inherit_fields' => [ 'global_Mixin' ],
  'fields'    =>  {
    'queueids'       => { 'name' => 'Queues',
                          'type' => 'select-rt-queue',
                          %multiple,
                          'validate' => sub { return ${$_[1]} ? '' : 'Queue must be specified' },
                        },
    'unit_field'     => { 'name' => 'Units field',
                          %custom_field,
                          'validate' => sub { return ${$_[1]} ? '' : 'Units field must be specified' },
                        },
    'rate_field'     => { 'name' => 'Charge per unit (from RT field)',
                          %custom_field,
                          'empty_label' => '',
                        },
	'rate_flat'      => { 'name' => 'Charge per unit (flat)',
                          'validate' => \&FS::part_pkg::global_Mixin::validate_moneyn },
    'display_fields' => { 'name' => 'Display fields',
                          %custom_field,
                          %multiple,
                        },
    # from global_Mixin, but don't get used by this at all
    'unused_credit_cancel'  => {'disabled' => 1},
    'unused_credit_suspend' => {'disabled' => 1},
    'unused_credit_change'  => {'disabled' => 1},
  },
  'validate' => sub {
    my $options = shift;
    return 'Rate must be specified'
      unless $options->{'rate_field'} or $options->{'rate_flat'};
    return 'Cannot specify both flat rate and rate field'
      if $options->{'rate_field'} and $options->{'rate_flat'};
    return '';
  },
  'fieldorder' => [ 'queueids', 'unit_field', 'rate_field', 'rate_flat', 'display_fields' ]
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= ' plus ' if $str;
    $str .= 'charge from RT';
# takes way too long just to get a package label
#    FS::TicketSystem->init();
#    my %custom_fields = FS::TicketSystem->custom_fields();
#    my $rate = $self->option('rate_flat',1);
#    my $rate_field = $self->option('rate_field',1);
#    my $unit_field = $self->option('unit_field');
#    $str .= $rate
#            ? $money_char . sprintf("%.2",$rate)
#            : $custom_fields{$rate_field};
#    $str .= ' x ' . $custom_fields{$unit_field};
    return $str;
}

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += ($cust_pkg->quantity || 1) * $self->calc_recur_Common(@_);

  $charges;

}

sub can_discount { 0; }

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  FS::TicketSystem->init();

  my %queues = FS::TicketSystem->queues(undef,'SeeCustomField');

  my @tickets;
  foreach my $queueid (
    split(', ',$self->option('queueids',1) || '')
  ) {

    die "Insufficient permission to invoice package"
      unless exists $queues{$queueid};

    # load all resolved tickets since pkg was ordered
    # will subtract previous charges below
    # only way to be sure we've caught everything
    my $tickets = FS::TicketSystem->customer_tickets({
      number   => $cust_pkg->custnum, 
      limit    => 10000, # arbitrarily large
      status   => 'resolved',
      queueid  => $queueid,
      resolved => $cust_pkg->order_date, # or setup? but this is mainly for installations,
                                         # and workflow might resolve tickets before first bill...
                                         # for now, expect pkg to be ordered before tickets get resolved,
                                         # easy enough to make a pkg option to use setup/sdate instead
    });
    push @tickets, @$tickets;
  };

  my $rate = $self->option('rate_flat',1);
  my $rate_field = $self->option('rate_field',1);
  my $unit_field = $self->option('unit_field');
  my @display_fields = split(', ',$self->option('display_fields',1) || '');

  my %custom_fields = FS::TicketSystem->custom_fields();
  my $rate_label = $rate
                   ? ''
                   : ' ' . $custom_fields{$rate_field};
  my $unit_label = $custom_fields{$unit_field};

  $rate_field = 'CF.{' . $rate_field . '}' if $rate_field;
  $unit_field = 'CF.{' . $unit_field . '}';

  my $charges = 0;
  foreach my $ticket ( @tickets ) {
    next unless $ticket->{$unit_field};
    next unless $rate || $ticket->{$rate_field};
    my $trate = $rate || $ticket->{$rate_field};
    my $tunit = $ticket->{$unit_field};
    my $subcharge = sprintf('%.2f', $trate * $tunit);
    my $precharge = _previous_charges( $cust_pkg->pkgnum, $ticket->{'id'} );
    $subcharge -= $precharge;

    # if field values for previous charges increased,
    # we can make additional charges here and now,
    # but if field values were decreased, we just ignore--
    # credits will have to be applied manually later, if that's what's intended
    next if $subcharge <= 0;

    my $rt_field_charge = new FS::rt_field_charge {
      'pkgnum' => $cust_pkg->pkgnum,
      'ticketid' => $ticket->{'id'},
      'rate' => $trate,
      'units' => $tunit,
      'charge' => $subcharge,
      '_date' => $$sdate,
    };
    my $error = $rt_field_charge->insert;
    die "Error inserting rt_field_charge: $error" if $error;
    push @$details, $money_char . sprintf('%.2f',$trate) . $rate_label . ' x ' . $tunit . ' ' . $unit_label;
    push @$details, ' - ' . $money_char . sprintf('%.2f',$precharge) . ' previously charged' if $precharge;
    foreach my $field (
      sort { $ticket->{'_cf_sort_order'}{$a} <=> $ticket->{'_cf_sort_order'}{$b} } @display_fields
    ) {
      my $label = $custom_fields{$field};
      my $value = $ticket->{'CF.{' . $field . '}'};
      push @$details, $label . ': ' . $value if $value;
    }
    $charges += $subcharge;
  }
  return $charges;
}

sub _previous_charges {
  my ($pkgnum, $ticketid) = @_;
  my $prev = 0;
  foreach my $rt_field_charge (
    qsearch('rt_field_charge', { pkgnum => $pkgnum, ticketid => $ticketid })
  ) {
    $prev += $rt_field_charge->charge;
  }
  return $prev;
}

1;
