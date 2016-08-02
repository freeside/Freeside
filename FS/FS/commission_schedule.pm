package FS::commission_schedule;
use base qw( FS::o2m_Common FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::commission_rate;
use Tie::IxHash;

tie our %basis_options, 'Tie::IxHash', (
  setuprecur    => 'Total sales',
  setup         => 'One-time and setup charges',
  recur         => 'Recurring charges',
  setup_cost    => 'Setup costs',
  recur_cost    => 'Recurring costs',
  setup_margin  => 'Setup charges minus costs',
  recur_margin_permonth => 'Monthly recurring charges minus costs',
);

=head1 NAME

FS::commission_schedule - Object methods for commission_schedule records

=head1 SYNOPSIS

  use FS::commission_schedule;

  $record = new FS::commission_schedule \%hash;
  $record = new FS::commission_schedule { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::commission_schedule object represents a bundle of one or more
commission rates for invoices. FS::commission_schedule inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item schedulenum - primary key

=item schedulename - descriptive name

=item reasonnum - the credit reason (L<FS::reason>) that will be assigned
to these commission credits

=item basis - for percentage credits, which component of the invoice charges
the percentage will be calculated on:
- setuprecur (total charges)
- setup
- recur
- setup_cost
- recur_cost
- setup_margin (setup - setup_cost)
- recur_margin_permonth ((recur - recur_cost) / freq)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new commission schedule.  To add the object to the database, see
L<"insert">.

=cut

sub table { 'commission_schedule'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  # don't allow the schedule to be removed if it's still linked to events
  if ($self->part_event) {
    return 'This schedule is still in use.'; # UI should be smarter
  }
  $self->process_o2m(
    'table'   => 'commission_rate',
    'params'  => [],
  ) || $self->delete;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('schedulenum')
    || $self->ut_text('schedulename')
    || $self->ut_number('reasonnum')
    || $self->ut_enum('basis', [ keys %basis_options ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_event

Returns a list of billing events (L<FS::part_event> objects) that pay
commission on this schedule.

=cut

sub part_event {
  my $self = shift;
  map { $_->part_event }
    qsearch('part_event_option', {
      optionname  => 'schedulenum',
      optionvalue => $self->schedulenum,
    }
  );
}

=item calc_credit INVOICE

Takes an L<FS::cust_bill> object and calculates credit on this schedule.
Returns the amount to credit. If there's no rate defined for this invoice,
returns nothing.

=cut

# Some false laziness w/ FS::part_event::Action::Mixin::credit_bill.
# this is a little different in that we calculate the credit on the whole
# invoice.

sub calc_credit {
  my $self = shift;
  my $cust_bill = shift;
  die "cust_bill record required" if !$cust_bill or !$cust_bill->custnum;
  # count invoices before or including this one
  my $cycle = FS::cust_bill->count('custnum = ? AND _date <= ?',
    $cust_bill->custnum,
    $cust_bill->_date
  );
  my $rate = qsearchs('commission_rate', {
    schedulenum => $self->schedulenum,
    cycle       => $cycle,
  });
  # we might do something with a rate that applies "after the end of the
  # schedule" (cycle = 0 or something) so that this can do commissions with
  # no end date. add that here if there's a need.
  return unless $rate;

  my $amount;
  if ( $rate->percent ) {
    my $what = $self->basis;
    my $cost = ($what =~ /_cost/ ? 1 : 0);
    my $margin = ($what =~ /_margin/ ? 1 : 0);
    my %part_pkg_cache;
    foreach my $cust_bill_pkg ( $cust_bill->cust_bill_pkg ) {

      my $charge = 0;
      next if !$cust_bill_pkg->pkgnum; # exclude taxes and fees

      my $cust_pkg = $cust_bill_pkg->cust_pkg;
      if ( $margin or $cost ) {
        # look up package costs only if we need them
        my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;
        my $part_pkg   = $part_pkg_cache{$pkgpart}
                     ||= FS::part_pkg->by_key($pkgpart);

        if ( $cost ) {
          $charge = $part_pkg->get($what);
        } else { # $margin
          $charge = $part_pkg->$what($cust_pkg);
        }

        $charge = ($charge || 0) * ($cust_pkg->quantity || 1);

      } else {

        if ( $what eq 'setup' ) {
          $charge = $cust_bill_pkg->get('setup');
        } elsif ( $what eq 'recur' ) {
          $charge = $cust_bill_pkg->get('recur');
        } elsif ( $what eq 'setuprecur' ) {
          $charge = $cust_bill_pkg->get('setup') +
                    $cust_bill_pkg->get('recur');
        }
      }

      $amount += ($charge * $rate->percent / 100);

    }
  } # if $rate->percent

  if ( $rate->amount ) {
    $amount += $rate->amount;
  }

  $amount = sprintf('%.2f', $amount + 0.005);
  return $amount;
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::part_event>, L<FS::commission_rate>

=cut

1;

