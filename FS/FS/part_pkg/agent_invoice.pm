package FS::part_pkg::agent_invoice;
use base qw(FS::part_pkg::recur_Common);

use strict;
use FS::Record qw( qsearch );
use FS::agent;
use FS::cust_main;
use FS::cust_bill_pkg_detail;
use Date::Format 'time2str';
use Text::CSV;

our $DEBUG = 0;

our $me = '[FS::part_pkg::agent_invoice]';

tie my %itemize_options, 'Tie::IxHash',
  'cust_bill' => 'one line per invoice',
  'cust_main' => 'one line per customer',
  'agent'     => 'one line per agent',
;

# use detail_formats for this?
my %itemize_header = (
  'cust_bill' => '"Inv #","Customer","Date","Charge"',
  'cust_main' => '"Cust #","Customer","Charge"',
  'agent'     => '',
);

our %info = (
  'name'      => 'Wholesale bulk billing based on actual invoice amounts, for master customers of an agent.',
  'shortname' => 'Wholesale billing for agent (invoice amounts)',
  'inherit_fields' => [qw( prorate_Mixin global_Mixin) ],
  'fields' => {
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
    'multiplier'    => { 'name' => 'Percentage of billed amount to charge' },
    'itemize'       => { 'name' => 'Display on the wholesale invoice',
                         'type' => 'select',
                         'select_options' => \%itemize_options,
                       },
  },
  'fieldorder' => [ qw( recur_method cutoff_day multiplier itemize ),
                    FS::part_pkg::prorate_Mixin::fieldorder,
                  ],

  'weight' => 53,

);

#some false laziness-ish w/ the other agent plan
sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $csv = Text::CSV->new({ binary => 1 });

  my $itemize = $self->option('itemize') || 'cust_bill';
  my $last_bill = $cust_pkg->last_bill;

  my $conf = new FS::Conf;
#  my $money_char = $conf->config('money_char') || '$';

  warn "$me billing for agent packages from ". time2str('%x', $last_bill).
                                       " to ". time2str('%x', $$sdate). "\n"
    if $DEBUG;

  # only invoices dated after $last_bill, but before or on $$sdate, will be
  # included in this wholesale bundle.
  # $last_bill is the last date the wholesale package was billed, unless
  # it has never been billed before, in which case it's the current time.
  # $$sdate is the date of the invoice we are now generating. It is one of:
  # - the bill date we are now billing, if there is one.
  # - or the wholesale package's setup date, if there is one
  # - or the current time
  # It will usually not be _after_ the current time. This can still happen
  # if this package's bill date is later in the current day than right now,
  # and next-bill-ignore-time is on.
  my $date_range = " AND _date <= $$sdate";
  if ( $last_bill ) {
    $date_range .= " AND _date > $last_bill";
  }

  my $percent = $self->option('multiplier') || 100;

  my $charged_cents = 0;
  my $wholesale_cents = 0;
  my $total = 0;

  my @agents = qsearch('agent', { 'agent_custnum' => $cust_pkg->custnum } );

  # The existing "agent" plan (based on package defined charges/costs) has to
  # ensure that all the agent's customers are billed before calculating its
  # fee, so that it can tell which packages were charged within the period.
  # _This_ plan has to do it because it actually uses the invoices. Either way
  # this behavior is not ideal, especially when using freeside-daily in 
  # multiprocess mode, since it can lead to billing all of the agent's 
  # customers within the master customer's billing job. If this becomes a
  # problem, one option is to use "freeside-daily -a" to bill the agent's
  # customers _first_, and master customers later.
  foreach my $agent (@agents) {

    warn "$me billing for agent ". $agent->agent. "\n"
      if $DEBUG;

    # cursor this if memory usage becomes a problem
    my @cust_main = qsearch('cust_main', { 'agentnum' => $agent->agentnum } );

    foreach my $cust_main (@cust_main) {

      warn "$me billing agent charges for ". $cust_main->name_short. "\n"
        if $DEBUG;

      # this option at least should propagate, or we risk generating invoices
      # in the apparent future and then leaving them out of this group
      my $error = $cust_main->bill( 'time' => $$sdate );

      die "Error pre-billing agent customer: $error" if $error;

      my @cust_bill = qsearch({
          table     => 'cust_bill',
          hashref   => { 'custnum' => $cust_main->custnum },
          extra_sql => $date_range,
          order_by  => ' ORDER BY _date ASC',
      });

      foreach my $cust_bill (@cust_bill) {

        # do we want the itemize setting to be purely cosmetic, or to actually
        # change how the calculation is done? for now let's make it purely
        # cosmetic, and round at the level of the individual invoice. can
        # change this if needed.
        $charged_cents += $cust_bill->charged * 100;
        $wholesale_cents += sprintf('%.0f', $cust_bill->charged * $percent);

        if ( $itemize eq 'cust_bill' ) {
          $csv->combine(
            $cust_bill->invnum,
            $cust_main->name_short,
            $cust_main->time2str_local('short', $cust_bill->_date),
            sprintf('%.2f', $wholesale_cents / 100),
          );
          my $detail = FS::cust_bill_pkg_detail->new({
              format    => 'C',
              startdate => $cust_bill->_date,
              amount    => sprintf('%.2f', $wholesale_cents / 100),
              detail    => $csv->string,
          });
          push @$details, $detail;

          $total += $wholesale_cents;
          $charged_cents = $wholesale_cents = 0;
        }

      }

      if ( $itemize eq 'cust_main' ) {

        $csv->combine(
          $cust_main->custnum,
          $cust_main->name_short,
          sprintf('%.2f', $wholesale_cents / 100),
        );
        my $detail = FS::cust_bill_pkg_detail->new({
            format => 'C',
            amount => sprintf('%.2f', $wholesale_cents / 100),
            detail => $csv->string,
        });
        push @$details, $detail;

        $total += $wholesale_cents;
        $charged_cents = $wholesale_cents = 0;
      }

    } # foreach $cust_main

    if ( $itemize eq 'agent' ) {
      $csv->combine(
        $cust_pkg->mt('[_1] customers', $agent->agent),
        sprintf('%.2f', $wholesale_cents / 100),
      );
      my $detail = FS::cust_bill_pkg_detail->new({
          format => 'C',
          amount => sprintf('%.2f', $wholesale_cents / 100),
          detail => $csv->string,
      });
      push @$details, $detail;

      $total += $wholesale_cents;
      $charged_cents = $wholesale_cents = 0;
    }

  } # foreach $agent

  if ( @$details and $itemize_header{$itemize} ) {
    unshift @$details, FS::cust_bill_pkg_detail->new({
        format => 'C',
        detail => $itemize_header{$itemize},
    });
  }

  my $charges = ($total / 100) + $self->calc_recur_Common(@_);

  sprintf('%.2f', $charges );

}

sub can_discount { 0; }

sub hide_svc_detail { 1; }

sub is_free { 0; }

sub can_usageprice { 0; }

1;

