<%

  my( $state, $country ) = $cgi->param('arg');

  my @counties = 
     sort
     map { s/[\n\r]//g; $_; }
     map { $_->county; }
     qsearch( 'cust_main_county',
              { 'state'   => $state,
                'country' => $country,
              },
            )
  ;


%>[ <%= join(', ', map { qq("$_") } @counties) %> ]
