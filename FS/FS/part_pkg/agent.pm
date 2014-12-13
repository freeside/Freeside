package FS::part_pkg::agent;

use strict;
use vars qw(@ISA $DEBUG $me %info);
use Date::Format;
use FS::Record qw( qsearch );
use FS::agent;
use FS::cust_main;

#use FS::part_pkg::recur_Common;;
#@ISA = qw(FS::part_pkg::recur_Common);
use FS::part_pkg::prorate;
@ISA = qw(FS::part_pkg::prorate);

$DEBUG = 0;

$me = '[FS::part_pkg::agent]';

%info = (
  'name'      => 'Wholesale bulk billing, for master customers of an agent.',
  'shortname' => 'Wholesale bulk billing for agent.',
  'inherit_fields' => [qw( prorate global_Mixin)],
  'fields' => {
    #'recur_method'  => { 'name' => 'Recurring fee method',
    #                     #'type' => 'radio',
    #                     #'options' => \%recur_method,
    #                     'type' => 'select',
    #                     'select_options' => \%recur_Common::recur_method,
    #                   },
    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28)',
                         'default' => '1',
                       },
    'add_full_period'=> { 'name' => 'When prorating first month, also bill '.
                                    'for one full period after that',
                          'type' => 'checkbox',
                        },

    'no_pkg_prorate'   => { 'name' => 'Disable prorating bulk packages (charge full price for packages active only a portion of the month)',
                            'type' => 'checkbox',
                          },

    'display_separate_cust'=> { 'name' => 'Separate customer from package display on invoices',
                                'type' => 'checkbox',
                              },

    'cost_only' => { 'name' => 'Bill wholesale on cost only, disabling the price fallback',
                     'type' => 'checkbox' 
                   },

  },

  'fieldorder' => [qw( cutoff_day add_full_period no_pkg_prorate ) ],

  'weight' => 52,

);

#some false laziness-ish w/bulk.pm...  not a lot
sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $last_bill = $cust_pkg->last_bill;

  return sprintf("%.2f", $self->SUPER::calc_recur(@_) )
    unless $$sdate > $last_bill;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';
  my $date_format = $conf->config('date_format') || '%m/%d/%Y';

  my $total_agent_charge = 0;

  warn "$me billing for agent packages from ". time2str('%x', $last_bill).
                                       " to ". time2str('%x', $$sdate). "\n"
    if $DEBUG;

  my $prorate_ratio =   ( $$sdate                     - $last_bill )
                      / ( $self->add_freq($last_bill) - $last_bill );

  #almost always just one,
  #unless you have multiple agents with same master customer0
  my @agents = qsearch('agent', { 'agent_custnum' => $cust_pkg->custnum } );

  foreach my $agent (@agents) {

    warn "$me billing for agent ". $agent->agent. "\n"
      if $DEBUG;

    #not the most efficient to load them all into memory,
    #but good enough for our current needs
    my @cust_main = qsearch('cust_main', { 'agentnum' => $agent->agentnum } );

    foreach my $cust_main (@cust_main) {

      warn "$me billing agent charges for ". $cust_main->name_short. "\n"
        if $DEBUG;

      #make sure setup dates are filled in
      my $error = $cust_main->bill; #options don't propogate from freeside-daily
      die "Error pre-billing agent customer: $error" if $error;

      my @cust_pkg = grep { my $setup  = $_->get('setup');
                            my $cancel = $_->get('cancel');

                            $setup < $$sdate  # END
                            && ( ! $cancel || $cancel > $last_bill ) #START
                          }
                     $cust_main->all_pkgs;

      my $cust_details = 0;

      foreach my $cust_pkg ( @cust_pkg ) {

        warn "$me billing agent charges for pkgnum ". $cust_pkg->pkgnum. "\n"
          if $DEBUG;

        my $pkg_details = '';

        my $cust_location = $cust_pkg->cust_location;
        $pkg_details .= $cust_location->locationname. ': '
          if $cust_location->locationname;

        my $part_pkg = $cust_pkg->part_pkg;

        # + something to identify package... primary service probably
        # no... package def for now
        $pkg_details .= $part_pkg->pkg. ': ';

        my $pkg_charge = 0;

        my $quantity = $cust_pkg->quantity || 1;

        my $pkg_setup_fee  = $part_pkg->setup_cost;
        $pkg_setup_fee ||= $part_pkg->option('setup_fee')
          unless $self->option('cost_only');
        $pkg_setup_fee ||= 0;

        my $pkg_base_recur = $part_pkg->recur_cost;
        $pkg_base_recur ||= $part_pkg->base_recur_permonth($cust_pkg)
          unless $self->option('cost_only');
        $pkg_base_recur ||= 0;

        my $pkg_start = $cust_pkg->get('setup');
        if ( $pkg_start < $last_bill ) {
          $pkg_start = $last_bill;
        } elsif ( $pkg_setup_fee ) {
          $pkg_charge += $quantity * $pkg_setup_fee;
          $pkg_details .= $money_char.
                          sprintf('%.2f setup', $quantity * $pkg_setup_fee );
          $pkg_details .= sprintf(" ($quantity \@ $money_char". '%.2f)',
                                  $pkg_setup_fee )
            if $quantity > 1;
          $pkg_details .= ', ';
        }

        my $pkg_end = $cust_pkg->get('cancel');
        $pkg_end = ( !$pkg_end || $pkg_end > $$sdate ) ? $$sdate : $pkg_end;

        my $pkg_recur_charge = $prorate_ratio * $pkg_base_recur;
        $pkg_recur_charge *= ( $pkg_end - $pkg_start )
                           / ( $$sdate  - $last_bill )
          unless $self->option('no_pkg_prorate');

        my $recur_charge += $pkg_recur_charge;

        if ( $recur_charge ) {
          $pkg_details .= $money_char.
                          sprintf('%.2f', $quantity * $recur_charge );
          $pkg_details .= sprintf(" ($quantity \@ $money_char". '%.2f)',
                                  $recur_charge )
            if $quantity > 1;
          $pkg_details .= ' ('.  time2str($date_format, $pkg_start).
                          ' - '. time2str($date_format, $pkg_end  ). ')';
        }

        $pkg_charge += $quantity * $recur_charge;

        if ( $pkg_charge ) {
          if ( $self->option('display_separate_cust') ) {
            push @$details, $cust_main->name.':' unless $cust_details++;
            push @$details, '    '.$pkg_details;
          } else {
            push @$details, $cust_main->name_short.': '. $pkg_details;
          }
        };

        $total_agent_charge += $pkg_charge;

      } #foreach $cust_pkg

      push @$details, ' ' if $cust_details;

    } #foreach $cust_main

  } #foreach $agent;

  my $charges = $total_agent_charge + $self->SUPER::calc_recur(@_); #prorate

  sprintf('%.2f', $charges );

}

sub can_discount { 0; }

sub hide_svc_detail {
  1;
}

sub is_free {
  0;
}

1;

