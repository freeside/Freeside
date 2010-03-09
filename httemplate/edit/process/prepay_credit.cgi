%unless ( ref($error) ) {
%  $cgi->param('error', $error );
<% $cgi->redirect(popurl(3). "edit/prepay_credit.cgi?". $cgi->query_string ) %>
% } else { 

<% include('/elements/header.html', "$num prepaid cards generated".
              ( $agent ? ' for '.$agent->agent : '' )
          )
%>

<FONT SIZE="+1">
% foreach my $card ( @$error ) { 

  <code><% $card %></code>
  -
  <% $hashref->{amount} ? sprintf('$%.2f', $hashref->{amount} ) : '' %>
  <% $hashref->{amount} && $hashref->{seconds} ? 'and' : '' %>
  <% $hashref->{seconds} ? duration_exact($hashref->{seconds}) : '' %>
  <% $hashref->{upbytes}   ? FS::UI::bytecount::bytecount_unexact($hashref->{upbytes}) : '' %>
  <% $hashref->{downbytes} ? FS::UI::bytecount::bytecount_unexact($hashref->{downbytes}) : '' %>
  <% $hashref->{totalbytes} ? FS::UI::bytecount::bytecount_unexact($hashref->{totalbytes}) : '' %>
  <br>
% } 

</FONT>

<% include('/elements/footer.html') %>

% } 
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

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

$hashref->{amount}    = $cgi->param('amount');
$hashref->{seconds}   = $cgi->param('seconds') * $cgi->param('multiplier');
$hashref->{upbytes}   = $cgi->param('upbytes') * $cgi->param('upmultiplier');
$hashref->{downbytes} = $cgi->param('downbytes') * $cgi->param('downmultiplier');
$hashref->{totalbytes} = $cgi->param('totalbytes') * $cgi->param('totalmultiplier');

$error ||= FS::prepay_credit::generate( $num,
                                        scalar($cgi->param('type')), 
                                        $cgi->param('length'),
                                        $hashref
                                      );

</%init>
