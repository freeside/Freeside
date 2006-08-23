%
%
%  my $country = $cgi->param('arg');
%  my @output = states_hash($country);
%
%
[ <% join(', ', map { qq("$_") } @output) %> ]
