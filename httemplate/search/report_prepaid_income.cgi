<% include("/elements/header.html", 'Prepaid Income (Unearned Revenue) Report') %>

<% include( '/elements/table-grid.html' ) %>

  <TR>
%   if ( scalar(@agentnums) > 1 ) {
      <TH CLASS="grid" BGCOLOR="#cccccc">Agent</TH>
%   }
    <TH CLASS="grid" BGCOLOR="#cccccc"><% $actual_label %>Unearned Revenue</TH>
%   if ( $legacy ) {
      <TH CLASS="grid" BGCOLOR="#cccccc">Legacy Unearned Revenue</TH>
%   }
  </TR>

% my $bgcolor1 = '#eeeeee';
% my $bgcolor2 = '#ffffff';
% my $bgcolor;
%
% push @agentnums, 0 unless scalar(@agentnums) < 2;
% foreach my $agentnum (@agentnums) {  
%
%   if ( $bgcolor eq $bgcolor1 ) {
%     $bgcolor = $bgcolor2;
%   } else {
%     $bgcolor = $bgcolor1;
%   }
%
%   my $alink = $agentnum ? "$link;agentnum=$agentnum" : $link;
%
%   my $agent_name = 'Total';
%   if ( $agentnum ) {
%     my $agent = qsearchs('agent', { 'agentnum' => $agentnum })
%       or die "unknown agentnum $agentnum";
%     $agent_name = $agent->agent;
%   }

    <TR>

%     if ( scalar(@agentnums) > 1 ) {
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $agent_name |h %></TD>
%     }

      <TD ALIGN="right" CLASS="grid" BGCOLOR="<% $bgcolor %>"><A HREF="<% $alink %>"><% $money_char %><% $total{$agentnum} %></A></TD>

%     if ( $legacy ) {
        <TD ALIGN="right" CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $now == $time ? $money_char.$total_legacy{$agentnum} : '<i>N/A</i>'%>
        </TD>
%     }

    </TR>

%  }

</TABLE>

<BR>
<% $actual_label %><% $actual_label ? 'u' : 'U' %>nearned revenue
is the amount of unearned revenue
<% $actual_label ? 'Freeside has actually' : '' %>
invoiced for packages with longer-than monthly terms.

% if ( $legacy ) {
  <BR><BR>
  Legacy unearned revenue is the amount of unearned revenue represented by 
  customer packages.  This number may be larger than actual unearned 
  revenue if you have imported longer-than monthly customer packages from
  a previous billing system.
% }

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my $legacy = $conf->exists('enable_legacy_prepaid_income');
my $actual_label = $legacy ? 'Actual ' : '';

#doesn't yet deal with daily/weekly packages

my $time = time;

my $now = $cgi->param('date') && str2time($cgi->param('date')) || $time;
$now =~ /^(\d+)$/ or die "unparsable date?";
$now = $1;

my $link = "cust_bill_pkg.cgi?nottax=1;unearned_now=$now";

my $curuser = $FS::CurrentUser::CurrentUser;

my $agentnum = '';
my @agentnums = ();
$agentnum ? ($agentnum) : $curuser->agentnums;
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  @agentnums = ($1);
  #XXX#push @where, "agentnum = $agentnum";
  #XXX#$link .= ";agentnum=$agentnum";
} else {
  @agentnums = $curuser->agentnums;
}

my @where = ();

#here is the agent virtualization
push @where, $curuser->agentnums_sql( 'table'=>'cust_main' );

#well, because cust_bill_pkg.cgi has it and without it the numbers don't match..
push @where , " payby != 'COMP' "
  unless $cgi->param('include_comp_cust');

my %total = ();
my %total_legacy = ();
foreach my $agentnum (@agentnums) {
  
  my $where = join(' AND ', @where, "cust_main.agentnum = $agentnum");
  $where = "AND $where" if $where;

  my( $total, $total_legacy ) = ( 0, 0 );

  # my @cust_bill_pkg =
  #   grep { $_->cust_pkg && $_->cust_pkg->part_pkg->freq !~ /^([01]|\d+[hdw])$/ }
  #     qsearch({
  #       'select'    => 'cust_bill_pkg.*',
  #       'table'     => 'cust_bill_pkg',
  #       'addl_from' => ' LEFT JOIN cust_bill USING ( invnum  ) '.
  #                      ' LEFT JOIN cust_main USING ( custnum ) ',
  #       'hashref'   => {
  #                        'recur' => { op=>'!=', value=>0    },
  #                        'sdate' => { op=>'<',  value=>$now },
  #                        'edate' => { op=>'>',  value=>$now },
  #                      },
  #       'extra_sql' => $where,
  #     });
  #
  #    foreach my $cust_bill_pkg ( @cust_bill_pkg) { 
  #      my $period = $cust_bill_pkg->edate - $cust_bill_pkg->sdate;
  #   
  #      my $elapsed = $now - $cust_bill_pkg->sdate;
  #      $elapsed = 0 if $elapsed < 0;
  #   
  #      my $remaining = 1 - $elapsed/$period;
  #   
  #      my $unearned = $remaining * $cust_bill_pkg->recur;
  #      $total += $unearned;
  #   
  #    }

  #re-written in sql:

  #false laziness w/cust_bill_pkg.cgi

  my $float = 'REAL'; #'DOUBLE PRECISION';

  my $period = "CAST(cust_bill_pkg.edate - cust_bill_pkg.sdate AS $float)";
  my $elapsed = "(CASE WHEN cust_bill_pkg.sdate > $now
                   THEN 0
                   ELSE ($now - cust_bill_pkg.sdate)
                 END)";
  #my $elapsed = "CAST($unearned - cust_bill_pkg.sdate AS $float)";

  my $remaining = "(1 - $elapsed/$period)";

  my $select = "SUM($remaining * cust_bill_pkg.recur)";

  #[...]

  my $sql = "SELECT $select FROM cust_bill_pkg
                            LEFT JOIN cust_pkg  USING ( pkgnum )
                            LEFT JOIN part_pkg  USING ( pkgpart )
                            LEFT JOIN cust_main USING ( custnum )
               WHERE pkgpart > 0
                 AND sdate < $now
                 AND edate > $now
                 AND cust_bill_pkg.recur != 0
                 AND part_pkg.freq != '0'
                 AND part_pkg.freq != '1'
                 AND part_pkg.freq NOT LIKE '%h'
                 AND part_pkg.freq NOT LIKE '%d'
                 AND part_pkg.freq NOT LIKE '%w'
                 $where
             ";

  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  my $total = $sth->fetchrow_arrayref->[0];

  $total = sprintf('%.2f', $total);
  $total{$agentnum} = $total;
  $total{0} += $total;

  if ( $legacy ) {

    #not yet rewritten in sql, but now not enabled by default

    my @cust_pkg = 
      grep { $_->part_pkg->recur != 0
             && $_->part_pkg->freq !~ /^([01]|\d+[dw])$/
           }
        qsearch({
          'select'    => 'cust_pkg.*',
          'table'     => 'cust_pkg',
          'addl_from' => ' LEFT JOIN cust_main USING ( custnum ) ',
          'hashref'   => { 'bill' => { op=>'>', value=>$now } },
          'extra_sql' => $where,
        });

    foreach my $cust_pkg ( @cust_pkg ) {
      my $period = $cust_pkg->bill - $cust_pkg->last_bill;
   
      my $elapsed = $now - $cust_pkg->last_bill;
      $elapsed = 0 if $elapsed < 0;
   
      my $remaining = 1 - $elapsed/$period;
   
      my $unearned = $remaining * $cust_pkg->part_pkg->recur; #!! only works for flat/legacy
      $total_legacy += $unearned;
   
    }

    $total_legacy = sprintf('%.2f', $total_legacy);
    $total_legacy{$agentnum} = $total_legacy;
    $total_legacy{0} += $total_legacy;

  }

}

$total{0} = sprintf('%.2f', $total{0});
$total_legacy{0} = sprintf('%.2f', $total_legacy{0});
  
</%init>
