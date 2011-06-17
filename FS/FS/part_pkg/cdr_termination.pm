package FS::part_pkg::cdr_termination;

use strict;
use base qw( FS::part_pkg::recur_Common );
use vars qw( $DEBUG %info );
use Tie::IxHash;
use FS::Record qw( qsearch ); #qsearchs );
use FS::cdr;
use FS::cdr_termination;

tie my %temporalities, 'Tie::IxHash',
  'upcoming'  => "Upcoming (future)",
  'preceding' => "Preceding (past)",
;

%info = (
  'name' => 'VoIP rating of CDR records for termination partners.',
  'shortname' => 'VoIP/telco CDR termination',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    #'cdr_column'    => { 'name' => 'Column from CDR records',
    #                     'type' => 'select',
    #                     'select_enum' => [qw(
    #                       dcontext
    #                       channel
    #                       dstchannel
    #                       lastapp
    #                       lastdata
    #                       accountcode
    #                       userfield
    #                       cdrtypenum
    #                       calltypenum
    #                       description
    #                       carrierid
    #                       upstream_rateid
    #                     )],
    #                   },

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
                         'default'        => 'simple2', #XXX test
                       },

    'usage_section' => { 'name' => 'Section in which to place separate usage charges',
                       },

    'summarize_usage' => { 'name' => 'Include usage summary with recurring charges when usage is in separate section',
                          'type' => 'checkbox',
                        },

    'usage_mandate' => { 'name' => 'Always put usage details in separate section',
                          'type' => 'checkbox',
                       },
    #eofalse

  },
                       #cdr_column
  'fieldorder' => [qw( recur_temporality recur_method cutoff_day ),
                       FS::part_pkg::prorate_Mixin::fieldorder, 
                       qw(
                       output_format usage_section summarize_usage usage_mandate
                     )
                  ],

  'weight' => 48,

);

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  #my $last_bill = $cust_pkg->last_bill;
  my $last_bill = $cust_pkg->get('last_bill'); #->last_bill falls back to setup

  return 0
    if $self->recur_temporality eq 'preceding'
    && ( $last_bill eq '' || $last_bill == 0 );

  # termination calculations

  my $term_percent = $cust_pkg->cust_main->cdr_termination_percentage;
  die "no customer termination percentage" unless $term_percent;

  my $output_format = $self->option('output_format', 'Hush!') || 'simple2';

  my $charges = 0;

  #find an svc_external record
  my @svc_external = map  { $_->svc_x }
                     grep { $_->part_svc->svcdb eq 'svc_external' }
                     $cust_pkg->cust_svc;

  die "cdr_termination package has no svc_external service"
    unless @svc_external;
  die "cdr_termination package has multiple svc_external services"
    if scalar(@svc_external) > 1;

  my $svc_external = $svc_external[0];

  # find CDRs:
  # - matching our customer via svc_external.id/title?  (and via what field?)

  #let's try carrierid for now, can always make it configurable or rewrite
  my $cdr_column = 'carrierid';

  my %hashref = ( 'freesidestatus' => 'done' );

  # try matching on svc_external.id for now... (or title?  if ints don't cut it)
  $hashref{$cdr_column} = $svc_external[0]->id; 

  # - with no cdr_termination.status

  my $termpart = 1; #or from an option

  #false lazienss w/search/cdr.html (i should be a part_termination method)
  my $where_term =
    "( cdr.acctid = cdr_termination.acctid AND termpart = $termpart ) ";
  #my $join_term = "LEFT JOIN cdr_termination ON ( $where_term )";
  my $extra_sql =
    "AND NOT EXISTS ( SELECT 1 FROM cdr_termination WHERE $where_term )";

  #may need to process in batches if there's waaay too many
  my @cdrs = qsearch({
    'table'     => 'cdr',
    #'addl_from' => $join_term,
    'hashref'   => \%hashref,
    'extra_sql' => "$extra_sql FOR UPDATE",
  });

  foreach my $cdr (@cdrs) {

    #add a cdr_termination record and the charges

    # XXX config?
    #my $term_price = sprintf('%.2f', $cdr->rated_price * $term_percent / 100 );
    my $term_price = sprintf('%.4f', $cdr->rated_price * $term_percent / 100 );

    my $cdr_termination = new FS::cdr_termination {
      'acctid'      => $cdr->acctid,
      'termpart'    => $termpart,
      'rated_price' => $term_price,
      'status'      => 'done',
    };

    my $error = $cdr_termination->insert;
    die $error if $error; #next if $error; #or just skip this one???  why?

    $charges += $term_price;

    # and add a line to the invoice

    my $call_details = $cdr->downstream_csv( 'format' => $output_format,
                                             'charge' => $term_price,
                                           );

    my $classnum = ''; #usage class?

    #option to turn off?  or just use squelch_cdr for the customer probably
    push @$details, [ 'C', $call_details, $term_price, $classnum ];

  }
    
  # eotermiation calculation

  $charges += $self->calc_recur_Common(@_);

  $charges;
}

sub is_free {
  0;
}

1;
