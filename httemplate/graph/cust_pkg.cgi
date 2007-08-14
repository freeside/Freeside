<% include('elements/monthly.html',
                'title'         => $agentname. 'Package Churn',
                'items'         => \@items,
                'labels'        => \%label,
                'graph_labels'  => \%graph_label,
                'colors'        => \%color,
                'links'         => \%link,
                'agentnum'      => $agentnum,
                'sprintf'       => '%u',
                'disable_money' => 1,
             )
%>
<%init>

#XXX use a different ACL for package churn?
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

#false laziness w/money_time.cgi, cust_bill_pkg.cgi

#XXX or virtual
my( $agentnum, $agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $agent;
}

my $agentname = $agent ? $agent->agent.' ' : '';

my @items = qw( setup_pkg susp_pkg cancel_pkg );

my %label = (
  'setup_pkg'  => 'New orders',
  'susp_pkg'   => 'Suspensions',
#  'unsusp' => 'Unsuspensions',
  'cancel_pkg' => 'Cancellations',
);
my %graph_label = %label;

my %color = (
  'setup_pkg'   => '00cc00', #green
  'susp_pkg'    => 'ff9900', #yellow
  #'unsusp'  => '', #light green?
  'cancel_pkg'  => 'cc0000', #red ? 'ff0000'
);

my %link = (
  'setup_pkg'  => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'setup_begin',
                    'toparam'   => 'setup_end',
                  },
  'susp_pkg'   => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'susp_begin',
                    'toparam'   => 'susp_end',
                  },
  'cancel_pkg' => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'cancel_begin',
                    'toparam'   => 'cancel_end',
                  },
);

</%init>
