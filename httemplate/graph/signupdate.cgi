<% include('elements/report.html',
            'title'       => $agentname . 'Customer signups by time of day',
            'items'       => [ 'signupdate' ],
            'data'        => [ \@count ],
            'row_labels'  => [ 'New customers' ],
            'colors'      => [ '00cc00' ], #green
            'col_labels'  => [ map { "$_:00" } @hours ],
            'links'       => [ \@links ],
            'graph_type'  => 'Bars',
            'nototal'     => 0,
            'sprintf'     => '%u',
            'disable_money' => 1,
            ) %>
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
my $usernum = $cgi->param('usernum');

my @hours = (0..23);
my @count = (0) x 24;
my %where;
$where{'agentnum'} = $agentnum if $agentnum;
$where{'usernum'}   = $usernum if $usernum;
my $sdate = $cgi->param('start_year').
            '-'.
            $cgi->param('start_month').
            '-01';
my $edate = ($cgi->param('end_year') + 
               ($cgi->param('end_month')==12)).
            '-'.
            ($cgi->param('end_month') % 12 + 1).
            '-01'; # first day of the next month

my $sql = "AND signupdate >= ".str2time($sdate).
          " AND signupdate < ".str2time($edate);

foreach my $cust (qsearch({ table   => 'cust_main', 
                            hashref => \%where,
                            extra_sql => $sql } )) {
  next if !$cust->signupdate;
  my $hour = time2str('%H',$cust->signupdate);
  $count[$hour]++;
}

my @links = ("${p}search/cust_main.html?" . 
              join (';', map {$_.'='.$where{$_}} (keys(%where))) ).
              ";signupdate_beginning=$sdate;signupdate_ending=$edate";
push @links, map { ";signuphour=$_" } @hours;
</%init>
