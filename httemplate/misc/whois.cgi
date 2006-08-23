%
%  my $svcnum = $cgi->param('svcnum');
%  my $custnum = $cgi->param('custnum');
%  my $domain = $cgi->param('domain');
%
%

<% include("/elements/header.html","Whois $domain", menubar(
  ( $custnum
    ? ( "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ()
  ),
  "View this domain (#$svcnum)" => "${p}view/svc_domain.cgi?$svcnum",
  "Main menu" => $p,
)) %>
% my $whois = eval { whois($domain) };
%   if ( $@ ) {
%     ( $whois = $@ ) =~ s/ at \/.*Net\/Whois\/Raw\.pm line \d+.*$//s;
%   } else {
%     $whois =~ s/^\n+//;
%   }
%

<PRE><% $whois %></PRE>
</BODY>
</HTML>
