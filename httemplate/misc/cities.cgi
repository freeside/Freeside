[ <% join(', ', map { qq("$_") } @cities) %> ]
<%init>

my( $county, $state, $country ) = $cgi->param('arg');
my @cities = cities($county, $state, $country);

</%init>
