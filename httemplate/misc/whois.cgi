<% include("/elements/header.html","Whois $domain", menubar(
  ( $custnum
    ? ( "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ()
  ),
  "View this domain (#$svcnum)" => "${p}view/svc_domain.cgi?$svcnum",
)) %>

<PRE><% $whois %></PRE>

<% include('/elements/footer.html') %>

<%init>

my $svcnum = $cgi->param('svcnum');
my $custnum = $cgi->param('custnum');
my $domain = $cgi->param('domain');

my $display_custnum;
if ( $custnum ) {
  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  $display_custnum = $cust_main->display_custnum;
}

my $whois = eval { whois($domain) };
  if ( $@ ) {
    ( $whois = $@ ) =~ s/ at \/.*Net\/Whois\/Raw\.pm line \d+.*$//s;
  } else {
    $whois =~ s/^\n+//;
  }

</%init>
