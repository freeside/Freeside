<%

  my $country = $cgi->param('arg');

  my @states = 
     sort
     map { s/[\n\r]//g; $_; }
     map { $_->state; }
     qsearch( 'cust_main_county',
              { 'country' => $country },
              'DISTINCT ON ( state ) *',
            )
  ;


%>[ <%= join(', ', map { qq("$_") } @states) %> ]
