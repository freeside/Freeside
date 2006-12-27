[ <% join(', ', map { qq("$_") } @counties) %> ]
<%init>

my( $state, $country ) = $cgi->param('arg');
my @counties = counties($state, $country);

</%init>
