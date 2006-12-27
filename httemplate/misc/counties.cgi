[ <% join(', ', map { qq("$_") } @counties) %> ]
<%init>

my $DEBUG = 0;

my( $state, $country ) = $cgi->param('arg');

warn "fetching counties for $state / $country \n"
  if $DEBUG;

my @counties = 
    sort
    map { s/[\n\r]//g; $_; }
    map { $_->county; }
    qsearch( {
      'select'  => 'DISTINCT county',
      'table'   => 'cust_main_county',
      'hashref' => { 'state'   => $state,
                     'country' => $country,
                   },
    } )
;

warn "counties: ". join(', ', map { qq("$_") } @counties). "\n"
  if $DEBUG;

</%init>
