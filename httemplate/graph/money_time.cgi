<% include('elements/monthly.html',
                'title'        => $agentname.
                                  'Sales, Credits and Receipts Summary',
                'items'        => \@items,
                'labels'       => \%label,
                'graph_labels' => \%graph_label,
                'colors'       => \%color,
                'links'        => \%link,
                'agentnum'     => $agentnum,
                'nototal'      => scalar($cgi->param('12mo')),
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

#XXX or virtual
my( $agentnum, $agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $agent;
}

my $agentname = $agent ? $agent->agent.' ' : '';

my @items = qw( invoiced netsales credits payments receipts );
if ( $cgi->param('12mo') == 1 ) {
  @items = map $_.'_12mo', @items;
}

my %label = (
  'invoiced' => 'Gross Sales',
  'netsales' => 'Net Sales',
  'credits'  => 'Credits',
  'payments' => 'Gross Receipts',
  'receipts' => 'Net Receipts',
);

my %graph_suffix = (
 'invoiced' => ' (invoiced)', 
 'netsales' => ' (invoiced - applied credits)',
 'credits'  => '',
 'payments' => ' (payments)',
 'receipts' => '/Cashflow (payments - refunds)',
);
my %graph_label = map { $_ => $label{$_}.$graph_suffix{$_} } keys %label;

$label{$_.'_12mo'} = $label{$_}. " (previous 12 months)"
  foreach keys %label;

$graph_label{$_.'_12mo'} = $graph_label{$_}. " (previous 12 months)"
  foreach keys %graph_label;

my %color = (
  'invoiced' => '9999ff', #light blue
  'netsales' => '0000cc', #blue
  'credits'  => 'cc0000', #red
  'payments' => '99cc99', #light green
  'receipts' => '00cc00', #green
);
$color{$_.'_12mo'} = $color{$_}
  foreach keys %color;

my %link = (
  'invoiced' => "${p}search/cust_bill.html?agentnum=$agentnum;",
  'netsales' => "${p}search/cust_bill.html?agentnum=$agentnum;net=1;",
  'credits'  => "${p}search/cust_credit.html?agentnum=$agentnum;",
  'payments' => "${p}search/cust_pay.cgi?magic=_date;agentnum=$agentnum;",
);
# XXX link 12mo?

</%init>
