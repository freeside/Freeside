<%
my $hashref = {};

my $agent = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agent = qsearchs('agent', { 'agentnum' => $hashref->{agentnum}=$1 } );
}

my $error = '';

my $num = 0;
if ( $cgi->param('num') =~ /^\s*(\d+)\s*$/ ) {
  $num = $1;
} else {
  $error = 'Illegal number of prepaid cards: '. $cgi->param('num');
}

$hashref->{amount} = $cgi->param('amount');
$hashref->{seconds} = $cgi->param('seconds') * $cgi->param('multiplier');

$error ||= FS::prepay_credit::generate( $num,
                                        scalar($cgi->param('type')), 
                                        $hashref
                                      );

unless ( ref($error) ) {
  $cgi->param('error', $error );
%><%=
  $cgi->redirect(popurl(3). "edit/prepay_credit.cgi?". $cgi->query_string )
%><% } else { %>

<%= header( "$num prepaid cards generated".
              ( $agent ? ' for '.$agent->agent : '' ),
            menubar( 'Main menu' => popurl(3) )
          )
%>

<FONT SIZE="+1">
<% foreach my $card ( @$error ) { %>
  <code><%= $card %></code>
  -
  <%= $hashref->{amount} ? sprintf('$%.2f', $hashref->{amount} ) : '' %>
  <%= $hashref->{amount} && $hashref->{seconds} ? 'and' : '' %>
  <%= $hashref->{seconds} ? duration_exact($hashref->{seconds}) : '' %>
  <br>
<% } %>

</FONT>

</BODY></HTML>
<% } %>
