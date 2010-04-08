<% include('elements/monthly.html',
                'title'        => $agentname.
                                  'Package Costs Report',
                'graph_type'   => 'Lines',
                'items'        => \@items,
                'labels'       => \%label,
                'graph_labels' => \%label,
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

my @items = qw( cust_pkg_setup_cost cust_pkg_recur_cost );
if ( $cgi->param('12mo') == 1 ) {
  @items = map $_.'_12mo', @items;
}

my %label = (
  'cust_pkg_setup_cost' => 'Setup Costs',
  'cust_pkg_recur_cost' => 'Recurring Costs',
);

$label{$_.'_12mo'} = $label{$_}. " (prev 12 months)"
  foreach keys %label;

my %color = (
  'cust_pkg_setup_cost' => '0000cc',
  'cust_pkg_recur_cost' => '00cc00',
);
$color{$_.'_12mo'} = $color{$_}
  foreach keys %color;

my %link = (
  'cust_pkg_setup_cost' => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                             'fromparam' => 'setup_begin',
                             'toparam'   => 'setup_end',
                           },
  'cust_pkg_recur_cost' => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                             'fromparam' => 'active_begin',
                             'toparam'   => 'active_end',
                           },
);
# XXX link 12mo?

</%init>
