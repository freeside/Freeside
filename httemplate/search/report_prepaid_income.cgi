<% include("/elements/header.html", 'Prepaid Income (Unearned Revenue) Report') %>

<% table() %>
  <TR>
    <TH>Actual Unearned Revenue</TH>
    <TH>Legacy Unearned Revenue</TH>
  </TR>
  <TR>
    <TD ALIGN="right">$<% $total %>
    <TD ALIGN="right">
      <% $now == $time ? "\$$total_legacy" : '<i>N/A</i>'%>
    </TD>
  </TR>

</TABLE>
<BR>
Actual unearned revenue is the amount of unearned revenue Freeside has  
actually invoiced for packages with longer-than monthly terms.
<BR><BR>
Legacy unearned revenue is the amount of unearned revenue represented by 
customer packages.  This number may be larger than actual unearned 
revenue if you have imported longer-than monthly customer packages from
a previous billing system.
</BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

#doesn't yet deal with daily/weekly packages

#needs to be re-written in sql for efficiency

my $time = time;

my $now = $cgi->param('date') && str2time($cgi->param('date')) || $time;
$now =~ /^(\d+)$/ or die "unparsable date?";
$now = $1;

my( $total, $total_legacy ) = ( 0, 0 );

my @cust_bill_pkg =
  grep { $_->cust_pkg && $_->cust_pkg->part_pkg->freq !~ /^([01]|\d+[dw])$/ }
    qsearch( 'cust_bill_pkg', {
                                'recur'     => { op=>'!=', value=>0 },
                                'edate'     => { op=>'>', value=>$now },
                                'duplicate' => '',
                              }, );

my @cust_pkg = 
  grep { $_->part_pkg->recur != 0
         && $_->part_pkg->freq !~ /^([01]|\d+[dw])$/
       }
    qsearch ( 'cust_pkg', {
                            'bill' => { op=>'>', value=>$now }
                          } );

foreach my $cust_bill_pkg ( @cust_bill_pkg) { 
  my $period = $cust_bill_pkg->edate - $cust_bill_pkg->sdate;

  my $elapsed = $now - $cust_bill_pkg->sdate;
  $elapsed = 0 if $elapsed < 0;

  my $remaining = 1 - $elapsed/$period;

  my $unearned = $remaining * $cust_bill_pkg->recur;
  $total += $unearned;

}

foreach my $cust_pkg ( @cust_pkg ) {
  my $period = $cust_pkg->bill - $cust_pkg->last_bill;

  my $elapsed = $now - $cust_pkg->last_bill;
  $elapsed = 0 if $elapsed < 0;

  my $remaining = 1 - $elapsed/$period;

  my $unearned = $remaining * $cust_pkg->part_pkg->recur; #!! only works for flat/legacy
  $total_legacy += $unearned;

}

$total = sprintf('%.2f', $total);
$total_legacy = sprintf('%.2f', $total_legacy);

</%init>
