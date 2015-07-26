<% include('elements/monthly.html',
                'title'        => $agentname. $referralname.
                                  'Sales, Credits and Receipts Summary',
                'items'        => \@items,
                'labels'       => \%label,
                'graph_labels' => \%graph_label,
                'colors'       => \%color,
                'links'        => \%link,
                'agentnum'     => $agentnum,
                'refnum'       => $refnum,
                'cust_classnum'=> \@classnums,
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

my @classnums;
if ( $cgi->param('cust_classnum') ) {
  @classnums = grep /^\d+$/, $cgi->param('cust_classnum');
}

my( $refnum, $part_referral ) = ('', '');
if ( $cgi->param('refnum') =~ /^(\d+)$/ ) {
  $refnum = $1;
  $part_referral = qsearchs('part_referral', { 'refnum' => $refnum } );
  die "refnum $refnum not found!" unless $part_referral;
}
my $referralname = $part_referral ? $part_referral->referral.' ' : '';

# need to clean this up. the false symmetry of "gross" and "net" everything
# makes it aesthetically hard to make this report more useful.
my @items = ($cgi->param('exclude_discount') ? 'invoiced' : 'gross');
push @items,
            qw( discounted   netsales
                credits  netcredits
                payments receipts
                refunds  netrefunds
                cashflow netcashflow
            );

my %label = (
  'gross'       => 'Gross Sales',
  'invoiced'    => 'Invoiced Sales',
  'netsales'    => 'Net Sales',
  'discounted'  => 'Discounts',
  'credits'     => 'Gross Credits',
  'netcredits'  => 'Net Credits',
  'payments'    => 'Gross Receipts',
  'receipts'    => 'Net Receipts',
  'refunds'     => 'Gross Refunds',
  'netrefunds'  => 'Net Refunds',
  'cashflow'    => 'Gross Cashflow',
  'netcashflow' => 'Net Cashflow',
);

my %graph_suffix = (
 'gross'       => ' (invoiced + discounts)', 
 'invoiced'    => '',
 'netsales'    => ' (invoiced - applied credits)',
 'discounted'  => '',
 'credits'     => ' (credited)',
 'netcredits'  => ' (applied credits)',
 'payments'    => ' (payments)',
 'receipts'    => ' (applied payments)',
 'refunds'     => ' (refunds)',
 'netrefunds'  => ' (applied refunds)',
 'cashflow'    => ' (payments - refunds)',
 'netcashflow' => ' (applied payments - applied refunds)',
);
my %graph_label = map { $_ => $label{$_}.$graph_suffix{$_} } keys %label;

my %color = (
  'gross'       => '9999ff', #light blue
  'invoiced'    => '9999ff', #light blue
  'netsales'    => '0000cc', #blue
  'credits'     => 'ff9999', #light red
  'netcredits'  => 'cc0000', #red
  'payments'    => '99cc99', #light green
  'receipts'    => '00cc00', #green
  'refunds'     => 'ffcc99', #light orange
  'netrefunds'  => 'ff9900', #orange
  'cashflow'    => '99cc33', #light olive
  'netcashflow' => '339900', #olive
  'discounted'  => 'cc33cc', #purple-ish?
);
$color{$_.'_12mo'} = $color{$_}
  foreach keys %color;

my $ar = "agentnum=$agentnum;refnum=$refnum";
$ar .= ";cust_classnum=$_" foreach @classnums;

my %link = (
  'gross'      => "${p}search/cust_bill.html?$ar;",
  'invoiced'   => "${p}search/cust_bill.html?$ar;invoiced=1;",
  'netsales'   => "${p}search/cust_bill.html?$ar;net=1;",
  'credits'    => "${p}search/cust_credit.html?$ar;",
  'netcredits' => "${p}search/cust_credit_bill.html?$ar;",
  'payments'   => "${p}search/cust_pay.html?magic=_date;$ar;",
  'receipts'   => "${p}search/cust_bill_pay.html?$ar;",
  'refunds'    => "${p}search/cust_refund.html?magic=_date;$ar;",
  'netrefunds' => "${p}search/cust_credit_refund.html?$ar;",
  'discounted' => "${p}search/cust_bill_pkg_discount.html?$ar;",
);
# XXX link 12mo?

if ( $cgi->param('12mo') ) {
  $label{$_} .= " (prev 12 months)"
    foreach keys %label;

  $graph_label{$_} .= " (prev 12 months)"
    foreach keys %graph_label;
}

</%init>
