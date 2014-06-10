package FS::part_pkg::agent_cdr;
use base qw( FS::part_pkg::recur_Common );

#kind of glommed together from cdr_termination, agent, voip_cdr
# some false laziness w/ all of them

use strict;
use vars qw( $DEBUG $me %info );
use FS::Record qw( qsearch );
use FS::PagedSearch qw( psearch );
use FS::agent;
use FS::cust_main;
use FS::cdr;

$DEBUG = 0;

$me = '[FS::part_pkg::agent_cdr]';

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

%info = (
  'name'      => 'Wholesale CDR cost billing, for master customers of an agent.',
  'shortname' => 'Whilesale CDR cost billing for agent.',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => { #false laziness w/cdr_termination

    #false laziness w/flat.pm
    'recur_temporality' => { 'name' => 'Charge recurring fee for period',
                             'type' => 'select',
                             'select_options' => \%temporalities,
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

    #false laziness w/voip_cdr.pm
    'output_format' => { 'name' => 'CDR invoice display format',
                         'type' => 'select',
                         'select_options' => { FS::cdr::invoice_formats() },
                         'default'        => 'simple2', #with source
                       },
    #eofalse

  },

  'fieldorder' => [ qw( recur_temporality recur_method cutoff_day ),
                    FS::part_pkg::prorate_Mixin::fieldorder, 
                    qw( output_format ),
                  ],

  'weight' => 53,

);

sub calc_recur {
  my( $self, $cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  my $charges = 0;

  my $output_format = $self->option('output_format', 'Hush!') || 'simple2';

  #CDR calculations

  #false laziness w/agent.pm
  #almost always just one,
  #unless you have multiple agents with same master customer0
  my @agents = qsearch('agent', { 'agent_custnum' => $cust_pkg->custnum } );

  foreach my $agent (@agents) {

    warn "$me billing wholesale CDRs for agent ". $agent->agent. "\n"
      if $DEBUG;

    #not the most efficient to load them all into memory,
    #but good enough for our current needs
    my @cust_main = qsearch('cust_main', { 'agentnum' => $agent->agentnum } );

    foreach my $cust_main (@cust_main) {

      warn "$me billing agent wholesale CDRs for ". $cust_main->name_short. "\n"
        if $DEBUG;

      #eofalse laziness w/agent.pm

      my @svcnum = ();
      foreach my $cust_pkg ( $cust_main->cust_pkg ) {
        push @svcnum, map $_->svcnum, $cust_pkg->cust_svc( svcdb=>'svc_phone' );
      }

      next unless @svcnum;

      #false laziness w/cdr_termination

      my $termpart = 1; #or from an option -- we're not termination, we're wholesale?  for now, use one or the other

      #false lazienss w/search/cdr.html (i should be a part_termination method)
      my $where_term =
        "( cdr.acctid = cdr_termination.acctid AND termpart = $termpart ) ";
      #my $join_term = "LEFT JOIN cdr_termination ON ( $where_term )";
      my $extra_sql =
        "AND NOT EXISTS ( SELECT 1 FROM cdr_termination WHERE $where_term )";

      #eofalse laziness w/cdr_termination.pm

      #false laziness w/ svc_phone->psearch_cdrs, kinda
      my $cdr_search = psearch({
        'table'     => 'cdr',
        #'addl_from' => $join_term,
        'hashref'   => {},
        'extra_sql' => " WHERE freesidestatus IN ( 'rated', 'done' ) ".
                       "   AND svcnum IN (". join(',', @svcnum). ") ".
                       $extra_sql,
        'order_by'  => 'ORDER BY startdate FOR UPDATE ',

      });

      #false laziness w/voip_cdr
      $cdr_search->limit(1000);
      $cdr_search->increment(0); #because we're adding cdr_termination as we go?
      while ( my $cdr = $cdr_search->fetch ) {

        my $cost = $cdr->rate_cost;
        #XXX exception handling?  return undef? (and err?) ref to a scalar err?

        #false laziness w/cdr_termination

        #add a cdr_termination record and the charges

        my $cdr_termination = new FS::cdr_termination {
          'acctid'      => $cdr->acctid,
          'termpart'    => $termpart,
          'rated_price' => $cost,
          'status'      => 'done',
        };

        my $error = $cdr_termination->insert;
        die $error if $error; #next if $error; #or just skip this one???  why?

        $charges += $cost;

        # and add a line to the invoice

        my $call_details = $cdr->downstream_csv( 'format' => $output_format,
                                                 'charge' => $cost,
                                               );
        my $classnum = ''; #usage class?

       #option to turn off?  or just use squelch_cdr for the customer probably
        push @$details, [ 'C', $call_details, $cost, $classnum ];

        #eofalse laziness w/cdr_termination

      }

    }

  }

  #eo CDR calculations

  $charges += ($cust_pkg->quantity || 1) * $self->calc_recur_Common(@_);

  $charges;
}

sub can_discount { 0; }

#?  sub hide_svc_detail { 1; }

sub is_free { 0; }

sub can_usageprice { 0; }

1;
