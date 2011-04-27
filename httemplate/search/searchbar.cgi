<%init>
my %searches = (
  'customers' => 'cust_main.cgi?search_cust=',
  'prospects' => 'prospect_main.html?search_prospect=',
  'invoices'  => 'cust_bill.html?invnum=',
  'services'  => 'cust_svc.html?search_svc=',
);
if ( FS::Conf->new->config('ticket_system') ) {
  $searches{'tickets'} = FS::TicketSystem->baseurl . 'index.html?q=';
}

$cgi->param('search_for') =~ /^(\w+)$/;
my $search = $searches{$1} or die "unknown search type: '$1'\n";
my $q = $cgi->param('q'); # pass through unparsed
</%init>
<% $cgi->redirect($search . $q) %>
