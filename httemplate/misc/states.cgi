[ <% join(', ', map { qq("$_") } @output) %> ]
<%init>

my $country = $cgi->param('arg');
my @output = states_hash($country);

</%init>
