<% include("/elements/header.html", "$agentname Tax Report - ".
              ( $beginning
                  ? time2str('%h %o %Y ', $beginning )
                  : ''
              ).
              'through '.
              ( $ending == 4294967295
                  ? 'now'
                  : time2str('%h %o %Y', $ending )
              )
          )
%>
<TD ALIGN="right">
Download full results<BR>
as <A HREF="<% $p.'search/report_tax-xls.cgi?'.$cgi->query_string%>">Excel spreadsheet</A>
</TD>

<STYLE type="text/css">
td.sectionhead {
  background-color: #777777;
  color: #ffffff;
  font-weight: bold;
  text-align: left;
}
</STYLE>
<% include('/elements/table-grid.html') %>
  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=9>Sales</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3>Rate</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3>Tax owed</TH>
% unless ( $cgi->param('show_taxclasses') ) { 
      <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3>Tax invoiced</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3>Tax credited</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=3>Tax collected</TH>
% } 
  </TR>

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2>Total</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=1>Non-taxable</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=1>Non-taxable</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=1>Non-taxable</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc" ROWSPAN=2>Taxable</TH>
  </TR>

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>(tax-exempt customer)</FONT></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>(tax-exempt package)</FONT></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>(monthly exemption)</FONT></TH>
  </TR>

% foreach my $class (@pkgclasses ) {
%   next if @{ $class->{regions} } == 0;
%   if ( $class->{classname} ) {
  <TR>
    <TD COLSPAN=19 CLASS="sectionhead"><% $class->{classname} %></TD>
  </TR>
%   }

% my $bgcolor1 = '#eeeeee';
% my $bgcolor2 = '#ffffff';
% my $bgcolor;

% my @regions = @{ $class->{regions} };
% foreach my $region ( @regions ) {
%
%   my $link = '';
%   if ( $with_pkgclass and length($class->{classnum}) ) {
%     $link = ';classnum='.$class->{classnum};
%   } # else we're not breaking down pkg class, or this is the grand total
%
%   if ( $region->{'label'} eq $out ) {
%     $link .= ';out=1';
%   } elsif ( $region->{'taxnums'} ) {
%     # might be nicer to specify this as country:state:city
%     $link .= ';'.join(';', map { "taxnum=$_" } @{ $region->{'taxnums'} });
%   }
%
%   if ( $bgcolor eq $bgcolor1 ) {
%     $bgcolor = $bgcolor2;
%   } else {
%     $bgcolor = $bgcolor1;
%   }
%
%   my $hicolor = $bgcolor;
%   unless ( $cgi->param('show_taxclasses') ) {
%     my $diff = abs(   sprintf( '%.2f', $region->{'owed'} )
%                     - sprintf( '%.2f', $region->{'tax'}  )
%                   );
%     if ( $diff > 0.02 ) {
%       $hicolor = $hicolor eq '#eeeeee' ? '#eeee99' : '#ffffcc';
%     }
%   }
%
%
%   my $td = qq(TD CLASS="grid" BGCOLOR="$bgcolor");
%   my $tdh = qq(TD CLASS="grid" BGCOLOR="$hicolor");
%   my $bigmath = '<FONT FACE="sans-serif" SIZE="+1"><B>';
%   my $bme = '</B></FONT>';

%   if ( $region->{'is_total'} ) {
    <TR STYLE="font-style: italic">
      <TD STYLE="text-align: right; padding-right: 1ex; background-color:<%$bgcolor%>">Total</TD>
%   } else {
    <TR>
      <<%$td%>><% $region->{'label'} %></TD>
%   }
      <<%$td%> ALIGN="right">
        <A HREF="<% $baselink. $link %>;nottax=1"
        ><% &$money_sprintf( $region->{'sales'} ) %></A>
      </TD>
%   if ( $region->{'label'} eq $out ) {
      <<%$td%> COLSPAN=12></TD>
%   } else { #not $out
      <<%$td%>><FONT SIZE="+1"><B> - </B></FONT></TD>
      <<%$td%> ALIGN="right">
        <A HREF="<% $baselink. $link %>;nottax=1;exempt_cust=Y"
        ><% &$money_sprintf( $region->{'exempt_cust'} ) %></A>
      </TD>
      <<%$td%>><FONT SIZE="+1"><B> - </B></FONT></TD>
      <<%$td%> ALIGN="right">
        <A HREF="<% $baselink. $link %>;nottax=1;exempt_pkg=Y"
        ><% &$money_sprintf( $region->{'exempt_pkg'} ) %></A>
      </TD>
      <<%$td%>><FONT SIZE="+1"><B> - </B></FONT></TD>
      <<%$td%> ALIGN="right">
        <A HREF="<% $exemptlink. $link %>"
        ><% &$money_sprintf( $region->{'exempt_monthly'} ) %></A>
        </TD>
      <<%$td%>><FONT SIZE="+1"><B> = </B></FONT></TD>
      <<%$td%> ALIGN="right">
        <A HREF="<% $baselink. $link %>;nottax=1;taxable=1"
        ><% &$money_sprintf( $region->{'taxable'} ) %></A>
      </TD>
      <<%$td%>><% $region->{'label'} eq 'Total' ? '' : "$bigmath X $bme" %></TD>
      <<%$td%> ALIGN="right"><% $region->{'rate'} %></TD>
      <<%$td%>><% $region->{'label'} eq 'Total' ? '' : "$bigmath = $bme" %></TD>
      <<%$tdh%> ALIGN="right">
        <% &$money_sprintf( $region->{'owed'} ) %>
      </TD>
%   } # if !$out
%   unless ( $cgi->param('show_taxclasses') ) {
%     my $invlink = $region->{'url_param_inv'}
%                       ? ';'. $region->{'url_param_inv'}
%                       : $link;

%     if ( $region->{'label'} eq $out ) {
        <<%$td%> ALIGN="right">
          <A HREF="<% $baselink. $invlink %>;istax=1"
          ><% &$money_sprintf_nonzero( $region->{'tax'} ) %></A>
        </TD>
        <<%$td%>></TD>
        <<%$td%> ALIGN="right">
          <A HREF="<% $creditlink. $invlink %>;istax=1"
          ><% &$money_sprintf_nonzero( $region->{'credit'} ) %></A>
        </TD>
        <<%$td%> COLSPAN=2></TD>
%     } else { #not $out
        <<%$tdh%> ALIGN="right">
          <A HREF="<% $baselink. $invlink %>;istax=1"
          ><% &$money_sprintf( $region->{'tax'} ) %></A>
        </TD>
        <<%$tdh%>><FONT SIZE="+1"><B> - </B></FONT></TD>
        <<%$tdh%> ALIGN="right">
          <A HREF="<% $creditlink. $invlink %>;istax=1"
          ><% &$money_sprintf( $region->{'credit'} ) %></A>
        </TD>
        <<%$tdh%>><FONT SIZE="+1"><B> = </B></FONT></TD>
        <<%$tdh%> ALIGN="right">
          <% &$money_sprintf( $region->{'tax'} - $region->{'credit'} ) %>
        </TD>
%     }
%   } # show_taxclasses

    </TR>
% } # foreach $region

%} # foreach $class

</TABLE>

% if ( $cgi->param('show_taxclasses') ) {

    <BR>
    <% include('/elements/table-grid.html') %>
    <TR>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">Tax invoiced</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">Tax credited</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">Tax collected</TH>
    </TR>

%   #some false laziness w/above
%   foreach my $class (@pkgclasses) {
%   if ( $class->{classname} ) {
    <TR>
      <TD COLSPAN=6 CLASS="sectionhead"><% $class->{classname} %></TD>
    </TR>
%   }

%   my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor;
%
%   foreach my $region ( @{ $class->{base_regions} } ) {
%
%     my $link = '';
%     if ( $with_pkgclass and length($class->{classnum}) ) {
%       $link = ';classnum='.$class->{classnum};
%     }
%
%     if ( $region->{'label'} eq $out ) {
%       $link .= ';out=1';
%     } else {
%       $link .= ';'. $region->{'url_param'}
%         if $region->{'url_param'};
%     }
%
%     if ( $bgcolor eq $bgcolor1 ) {
%       $bgcolor = $bgcolor2;
%     } else {
%       $bgcolor = $bgcolor1;
%     }
%     my $td = qq(TD CLASS="grid" BGCOLOR="$bgcolor");
%     my $tdh = qq(TD CLASS="grid" BGCOLOR="$bgcolor");
%
%     #?
%     my $invlink = $region->{'url_param_inv'}
%                     ? ';'. $region->{'url_param_inv'}
%                     : $link;

      <TR>
        <<%$td%>><% $region->{'label'} %></TD>
%     if ( $region->{'label'} eq $out ) {
        <<%$td%> ALIGN="right">
          <A HREF="<% $baselink. $invlink %>;istax=1"
          ><% &$money_sprintf_nonzero( $region->{'tax'} ) %></A>
        </TD>
        <<%$td%>></TD>
        <<%$td%> ALIGN="right">
          <A HREF="<% $creditlink. $invlink %>;istax=1"
          ><% &$money_sprintf_nonzero( $region->{'credit'} ) %></A>
        </TD>
        <<%$td%> COLSPAN=2></TD>
%     } else { #not $out
        <<%$td%> ALIGN="right">
          <A HREF="<% $baselink. $link %>;istax=1"
          ><% &$money_sprintf( $region->{'tax'} ) %></A>
        </TD>
        <<%$td%>><FONT SIZE="+1"><B> - </B></FONT></TD>
        <<%$tdh%> ALIGN="right">
          <A HREF="<% $creditlink. $invlink %>;istax=1"
          ><% &$money_sprintf( $region->{'credit'} ) %></A>
        </TD>
        <<%$td%>><FONT SIZE="+1"><B> = </B></FONT></TD>
        <<%$tdh%> ALIGN="right">
          <% &$money_sprintf( $region->{'tax'} - $region->{'credit'} ) %>
        </TD>
      </TR>
%     } # if $out
%   } #foreach $region
% } #foreach $class

  </TABLE>

% } # if show_taxclasses

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $DEBUG = $cgi->param('debug') || 0;

my $conf = new FS::Conf;

my $out = 'Out of taxable region(s)';

my %label_opt = ( out => 1 ); #enable 'Out of Taxable Region' label
$label_opt{with_city} = 1     if $cgi->param('show_cities');
$label_opt{with_district} = 1 if $cgi->param('show_districts');

$label_opt{with_taxclass} = 1 if $cgi->param('show_taxclasses');

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

my $join_cust =     '     JOIN cust_bill      USING ( invnum  ) 
                      LEFT JOIN cust_main     USING ( custnum ) ';

my $join_cust_pkg = $join_cust.
                    ' LEFT JOIN cust_pkg      USING ( pkgnum  )
                      LEFT JOIN part_pkg      USING ( pkgpart ) ';

my $from_join_cust_pkg = " FROM cust_bill_pkg $join_cust_pkg "; 

my $with_pkgclass = $cgi->param('show_pkgclasses');

# Either or both of these can be used to link cust_bill_pkg to 
# cust_main_county. This one links a taxed line item (billpkgnum) to a tax rate
# (taxnum), and gives the amount of tax charged on that line item under that
# rate (as tax_amount).
my $pkg_tax = "SELECT SUM(amount) as tax_amount, taxnum, ".
  "taxable_billpkgnum AS billpkgnum ".
  "FROM cust_bill_pkg_tax_location JOIN cust_bill_pkg USING (billpkgnum) ".
  "GROUP BY taxable_billpkgnum, taxnum";

# This one links a tax-exempted line item (billpkgnum) to a tax rate (taxnum),
# and gives the amount of the tax exemption.  EXEMPT_WHERE should be replaced 
# with a real WHERE clause to further limit the tax exemptions that will be
# included.
my $pkg_tax_exempt = "SELECT SUM(amount) AS exempt_charged, billpkgnum, taxnum ".
  "FROM cust_tax_exempt_pkg EXEMPT_WHERE GROUP BY billpkgnum, taxnum";

my $where = "WHERE cust_bill._date >= $beginning AND cust_bill._date <= $ending ";
# SELECT/GROUP clauses for first-level queries
# classnum is a placeholder; they all go in one class in this case.
my $select = "SELECT NULL AS classnum, cust_main_county.taxnum, ";
my $group =  "GROUP BY cust_main_county.taxnum";
# SELECT/GROUP clauses for second-level (totals) queries
my $select_all = "SELECT NULL AS classnum, ";
my $group_all =  "";

if ( $with_pkgclass ) {
  $select = "SELECT COALESCE(part_pkg.classnum,0), cust_main_county.taxnum, ";
  $group =  "GROUP BY part_pkg.classnum, cust_main_county.taxnum";
  $select_all = "SELECT COALESCE(part_pkg.classnum,0), ";
  $group_all  = "GROUP BY COALESCE(part_pkg.classnum,0)";
}

my $agentname = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "agent not found" unless $agent;
  $agentname = $agent->agent;
  $where .= ' AND cust_main.agentnum = '. $agent->agentnum;
}

my $nottax = 
  '(cust_bill_pkg.pkgnum != 0 OR cust_bill_pkg.feepart IS NOT NULL)';

# one query for each column of the report
# plus separate queries for the totals row
my (%sql, %all_sql);

# SALES QUERIES (taxable sales, all types of exempt sales)
# -------------

# general form
my $exempt = "$select SUM(exempt_charged)
  FROM cust_main_county
  JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
  USING (taxnum)
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust_pkg $where AND $nottax $group";

my $all_exempt = "$select_all SUM(exempt_charged)
  FROM cust_main_county
  JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
  USING (taxnum)
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust_pkg $where AND $nottax
  $group_all";

# sales to tax-exempt customers
$sql{exempt_cust} = $exempt;
$sql{exempt_cust} =~ s/EXEMPT_WHERE/WHERE exempt_cust = 'Y' OR exempt_cust_taxname = 'Y'/;
$all_sql{exempt_cust} = $all_exempt;
$all_sql{exempt_cust} =~ s/EXEMPT_WHERE/WHERE exempt_cust = 'Y' OR exempt_cust_taxname = 'Y'/;

# sales of tax-exempt packages
$sql{exempt_pkg} = $exempt;
$sql{exempt_pkg} =~ s/EXEMPT_WHERE/WHERE exempt_setup = 'Y' OR exempt_recur = 'Y'/;
$all_sql{exempt_pkg} = $all_exempt;
$all_sql{exempt_pkg} =~ s/EXEMPT_WHERE/WHERE exempt_setup = 'Y' OR exempt_recur = 'Y'/;

# monthly per-customer exemptions
$sql{exempt_monthly} = $exempt;
$sql{exempt_monthly} =~ s/EXEMPT_WHERE/WHERE exempt_monthly = 'Y'/;
$all_sql{exempt_monthly} = $all_exempt;
$all_sql{exempt_monthly} =~ s/EXEMPT_WHERE/WHERE exempt_monthly = 'Y'/;

# taxable sales
$sql{taxable} = "$select
  SUM(cust_bill_pkg.setup + cust_bill_pkg.recur - COALESCE(exempt_charged, 0))
  FROM cust_main_county
  JOIN ($pkg_tax) AS pkg_tax USING (taxnum)
  JOIN cust_bill_pkg USING (billpkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
    ON (pkg_tax_exempt.billpkgnum = cust_bill_pkg.billpkgnum 
        AND pkg_tax_exempt.taxnum = cust_main_county.taxnum)
  $join_cust_pkg $where AND $nottax $group";

# Here we're going to sum all line items that are taxable _at all_,
# under any tax.  exempt_charged is the sum of all exemptions for a 
# particular billpkgnum + taxnum; we take the taxnum that has the 
# smallest sum of exemptions and subtract that from the charged amount.
# 
# (This isn't an exact result, since line items can be taxable under 
# one tax and not another.  Under 4.x the tax report is designed to 
# consider only one variety of tax at a time, which should solve this.)

$all_sql{taxable} = "$select_all
  SUM(cust_bill_pkg.setup + cust_bill_pkg.recur - COALESCE(min_exempt, 0))
  FROM cust_bill_pkg
  JOIN (
    SELECT billpkgnum, MIN(exempt_charged) AS min_exempt
    FROM ($pkg_tax) AS pkg_tax
    JOIN cust_bill_pkg USING (billpkgnum)
    LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt USING (billpkgnum, taxnum)
    GROUP BY billpkgnum
  ) AS pkg_is_taxable 
  USING (billpkgnum)
  $join_cust_pkg $where AND $nottax $group_all";

$sql{taxable} =~ s/EXEMPT_WHERE//; # unrestricted
$all_sql{taxable} =~ s/EXEMPT_WHERE//;

# there isn't one for 'sales', because we calculate sales by adding up 
# the taxable and exempt columns.

# TAX QUERIES (billed tax, credited tax)
# -----------

# sum of billed tax:
# join cust_bill_pkg to cust_main_county via cust_bill_pkg_tax_location
my $taxfrom = " FROM cust_bill_pkg 
                $join_cust 
                LEFT JOIN cust_bill_pkg_tax_location USING ( billpkgnum )
                LEFT JOIN cust_main_county USING ( taxnum )";

if ( $with_pkgclass ) {
  # If we're not grouping by package class, this is unnecessary, and
  # probably really expensive.
  $taxfrom .= "
                LEFT JOIN cust_bill_pkg AS taxable
                  ON (cust_bill_pkg_tax_location.taxable_billpkgnum = taxable.billpkgnum)
                LEFT JOIN cust_pkg ON (taxable.pkgnum = cust_pkg.pkgnum)
                LEFT JOIN part_pkg USING (pkgpart)";
}

my $istax = "cust_bill_pkg.pkgnum = 0";
my $named_tax =
  "COALESCE(taxname,'Tax') = COALESCE(cust_bill_pkg.itemdesc,'Tax')";

$sql{tax} = "$select SUM(cust_bill_pkg_tax_location.amount)
             $taxfrom
             $where AND $istax AND $named_tax
             $group";

$all_sql{tax} = "$select_all SUM(cust_bill_pkg.setup)
             FROM cust_bill_pkg
             $join_cust
             $where AND $istax
             $group_all";

# sum of credits applied against billed tax
# ($creditfrom includes join of taxable item to part_pkg if with_pkgclass
# is on)
my $creditfrom = $taxfrom .
  ' JOIN cust_credit_bill_pkg USING (billpkgtaxlocationnum)' .
  ' JOIN cust_credit_bill     USING (creditbillnum)';
my $creditwhere = $where . 
  ' AND billpkgtaxratelocationnum IS NULL';
my $creditwhere_all = $where;

# if the credit_date option is set to application date, change
# $creditwhere accordingly
if ( $cgi->param('credit_date') eq 'cust_credit_bill' ) {
  $creditwhere     =~ s/cust_bill._date/cust_credit_bill._date/g;
  $creditwhere_all =~ s/cust_bill._date/cust_credit_bill._date/g;
}

$sql{credit} = "$select SUM(cust_credit_bill_pkg.amount)
                $creditfrom
                $creditwhere AND $istax AND $named_tax
                $group";

$all_sql{credit} = "$select_all SUM(cust_credit_bill_pkg.amount)
                FROM cust_credit_bill_pkg
                JOIN cust_bill_pkg USING (billpkgnum)
                $join_cust
                JOIN cust_credit_bill USING (creditbillnum)
                $creditwhere_all AND $istax
                $group_all";
warn "\n\n$all_sql{credit}\n\n";
if ( $with_pkgclass ) {
  # the slightly more complicated version, with lots of joins that are 
  # unnecessary if you're not breaking down by package class
  $all_sql{tax} = "$select_all SUM(cust_bill_pkg_tax_location.amount)
             $taxfrom
             $where AND $istax
             $group_all";

  $all_sql{credit} = "$select_all SUM(cust_credit_bill_pkg.amount)
                      $creditfrom
                      $creditwhere_all AND $istax
                      $group_all";
}

# "out of taxable region" sales
$all_sql{out_sales} = 
  "$select_all SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)
  FROM (cust_bill_pkg $join_cust_pkg)
  LEFT JOIN ($pkg_tax) AS pkg_tax USING (billpkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt USING (billpkgnum)
  $where AND $nottax
  AND pkg_tax.taxnum IS NULL AND pkg_tax_exempt.taxnum IS NULL
  $group_all"
;

$all_sql{out_sales} =~ s/EXEMPT_WHERE//;

my %data;
my %total;
foreach my $k (keys(%sql)) {
  my $stmt = $sql{$k};
  warn "\n".uc($k).":\n".$stmt."\n" if $DEBUG;
  my $sth = dbh->prepare($stmt);
  # three columns: classnum, taxnum, value
  $sth->execute 
    or die "failed to execute $k query: ".$sth->errstr;
  while ( my $row = $sth->fetchrow_arrayref ) {
    $data{$k}{$row->[0]}{$row->[1]} = $row->[2];
  }
}
warn "DATA:\n".Dumper(\%data) if $DEBUG > 1;

foreach my $k (keys %all_sql) {
  warn "\n".$all_sql{$k}."\n" if $DEBUG;
  my $sth = dbh->prepare($all_sql{$k});
  # two columns: classnum, value
  $sth->execute 
    or die "failed to execute $k totals query: ".$sth->errstr;
  while ( my $row = $sth->fetchrow_arrayref ) {
    $total{$k}{$row->[0]} = $row->[1];
  }
}
warn "TOTALS:\n".Dumper(\%total);# if $DEBUG > 1;
# so $data{tax}, for example, is now a hash with one entry
# for each classnum, containing a hash with one entry for each
# taxnum, containing the tax billed on that taxnum.
# if with_pkgclass is off, then the classnum is always null.

# integrity checks
# unlinked tax collected
my $out_tax_sql =
  "SELECT SUM(cust_bill_pkg.setup)
  FROM (cust_bill_pkg $join_cust)
  LEFT JOIN cust_bill_pkg_tax_location USING (billpkgnum)
  $where AND $istax AND cust_bill_pkg_tax_location.billpkgnum IS NULL"
;
my $unlinked_tax = FS::Record->scalar_sql($out_tax_sql);
# unlinked tax credited
my $out_credit_sql =
  "SELECT SUM(cust_credit_bill_pkg.amount)
  FROM cust_credit_bill_pkg
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust
  $where AND $istax AND cust_credit_bill_pkg.billpkgtaxlocationnum IS NULL"
;
my $unlinked_credit = FS::Record->scalar_sql($out_credit_sql);

# all sales
my $all_sales = FS::Record->scalar_sql(
  "SELECT SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)
  FROM cust_bill_pkg $join_cust $where AND $nottax"
);

#tax-report_groups filtering
my($group_op, $group_value) = ( '', '' );
if ( $cgi->param('report_group') =~ /^(=|!=) (.*)$/ ) {
  ( $group_op, $group_value ) = ( $1, $2 );
}
my $group_test = sub { # to be applied to a tax label
  my $label = shift;
  return 1 unless $group_op; #in case we get called inadvertantly
  if ( $label eq $out ) { #don't display "out of taxable region" in this case
    0;
  } elsif ( $group_op eq '=' ) {
    $label =~ /^$group_value/;
  } elsif ( $group_op eq '!=' ) {
    $label !~ /^$group_value/;
  } else {
    die "guru meditation #00de: group_op $group_op\n";
  }
};

my @pkgclasses;
if ($with_pkgclass) {
  @pkgclasses = qsearch('pkg_class', {});
  push @pkgclasses, FS::pkg_class->new({
    classnum  => '0',
    classname => 'Unclassified',
  });
} else {
  @pkgclasses = ( FS::pkg_class->new({
    classnum  => '',
    classname => '',
  }) );
}
my %pkgclass_data;

foreach my $class (@pkgclasses) {
  my $classnum = $class->classnum;
  my $classname = $class->classname;

  # if show_taxclasses is on, %base_regions will contain the same data
  # as %regions, but with taxclasses merged together (and ignoring report_group
  # filtering).
  my (%regions, %base_regions);

  my @loc_params = qw(country state county);
  push @loc_params, 'city' if $cgi->param('show_cities');
  push @loc_params, 'district' if $cgi->param('show_districts');

  foreach my $r ( qsearch({ 'table'     => 'cust_main_county', })) {
    my $taxnum = $r->taxnum;
    # set up a %regions entry for this region's tax label
    my $label = $r->label(%label_opt);
    next if $label eq $out;
    $regions{$label} ||= { label => $label };

    $regions{$label}->{$_} = $r->get($_) foreach @loc_params;
    $regions{$label}->{taxnums} ||= [];
    push @{ $regions{$label}->{taxnums} }, $r->taxnum;

    my %x; # keys are data items (like 'tax', 'exempt_cust', etc.)
    foreach my $k (keys %data) {
      next unless exists($data{$k}{$classnum}{$taxnum});
      $x{$k} = $data{$k}{$classnum}{$taxnum};
      $regions{$label}{$k} += $x{$k};
      if ( $k eq 'taxable' or $k =~ /^exempt/ ) {
        $regions{$label}->{'sales'} += $x{$k};
      }
    }

    my $owed = $data{'taxable'}{$classnum}{$taxnum} * ($r->tax/100);
    $regions{$label}->{'owed'} += $owed;
    $total{'owed'}{$classnum} += $owed;

    if ( defined($regions{$label}->{'rate'})
         && $regions{$label}->{'rate'} != $r->tax.'%' ) {
      $regions{$label}->{'rate'} = 'variable';
    } else {
      $regions{$label}->{'rate'} = $r->tax.'%';
    }

    if ( $cgi->param('show_taxclasses') ) {
      my $base_label = $r->label(%label_opt, 'with_taxclass' => 0);
      $base_regions{$base_label} ||=
      {
        label   => $base_label,
        tax     => 0,
        credit  => 0,
      };
      $base_regions{$base_label}->{tax}    += $x{tax};
      $base_regions{$base_label}->{credit} += $x{credit};
    }

  }

  my @regions = map { $_->{label} }
    sort {
      ($b eq $out) <=> ($a eq $out)
      or $a->{country} cmp $b->{country}
      or $a->{state}   cmp $b->{state}
      or $a->{county}  cmp $b->{county}
      or $a->{city}    cmp $b->{city}
    } 
    grep { $_->{sales} > 0 or $_->{tax} > 0 or $_->{credit} > 0 }
    values %regions;

  #tax-report_groups filtering
  @regions = grep &{$group_test}($_), @regions
    if $group_op;

  #calculate totals
  my %taxclasses = ();
  my %county = ();
  my %state = ();
  my %country = ();
  foreach my $label (@regions) {
    $taxclasses{$regions{$_}->{'taxclass'}} = 1
      if $regions{$_}->{'taxclass'};
    $county{$regions{$_}->{'county'}} = 1;
    $state{$regions{$_}->{'state'}} = 1;
    $country{$regions{$_}->{'country'}} = 1;
  }

  my $total_url_param = '';
  my $total_url_param_invoiced = '';
  if ( $group_op ) {

    my @country = keys %country;
    warn "WARNING: multiple countries on this grouped report; total links broken"
      if scalar(@country) > 1;
    my $country = $country[0];

    my @state = keys %state;
    warn "WARNING: multiple countries on this grouped report; total links broken"
      if scalar(@state) > 1;
    my $state = $state[0];

    $total_url_param_invoiced =
    $total_url_param =
      'report_group='.uri_escape("$group_op $group_value").';'.
      join(';', map 'taxclass='.uri_escape($_), keys %taxclasses );
    $total_url_param .= ';'.
      "country=$country;state=".uri_escape($state).';'.
      join(';', map 'county='.uri_escape($_), keys %county ) ;

  }

  #ordering
  @regions =
    map $regions{$_},
    sort { $a cmp $b }
    @regions;

  my @base_regions =
    map $base_regions{$_},
    sort { $a cmp $b }
    keys %base_regions;

  #add "Out of taxable" and total lines
  if ( $total{out_sales}{$classnum} ) {
    my %out = (
      'sales' => $total{out_sales}{$classnum},
      'label' => $out,
      'rate' => ''
    );
    push @regions, \%out;
    push @base_regions, \%out;
  }

  if ( @regions ) {
    my %class_total = map { $_ => $total{$_}{$classnum} } keys(%total);
    $class_total{is_total} = 1;
    $class_total{sales} = sum(
      @class_total{ 'taxable',
                    'out_sales',
                    grep(/^exempt/, keys %class_total) }
    );

    push @regions,      \%class_total;
    push @base_regions, \%class_total;
  }

  $pkgclass_data{$classname} = {
    classnum      => $classnum,
    classname     => $classname,
    regions       => \@regions,
    base_regions  => \@base_regions,
  };
}

if ( $with_pkgclass ) {
  my $class_zero = delete( $pkgclass_data{'Unclassified'} );
  @pkgclasses = map { $pkgclass_data{$_} }
                sort { $a cmp $b }
                keys %pkgclass_data;
  push @pkgclasses, $class_zero;

  my %grand_total = map {
    $_ => sum( values(%{ $total{$_} }) )
  } keys(%total);

  $grand_total{sales} = $all_sales;

  push @pkgclasses, {
    classnum      => '',
    classname     => 'Total',
    regions       => [ \%grand_total ],
    base_regions  => [ \%grand_total ],
  }
} else {
  @pkgclasses = $pkgclass_data{''};
}

#-- 

my $money_char = $conf->config('money_char') || '$';
my $money_sprintf = sub {
  $money_char. sprintf('%.2f', shift );
};
my $money_sprintf_nonzero = sub {
  $_[0] == 0 ? '' : &$money_sprintf($_[0])
};

my $dateagentlink = "begin=$beginning;end=$ending";
$dateagentlink .= ';agentnum='. $cgi->param('agentnum')
  if length($agentname);
my $baselink   = $p. "search/cust_bill_pkg.cgi?$dateagentlink";
my $exemptlink = $p. "search/cust_tax_exempt_pkg.cgi?$dateagentlink";

my $creditlink = $baselink . ";credit=1";
if ( $cgi->param('credit_date') eq 'cust_credit_bill' ) {
  $creditlink =~ s/begin/credit_begin/;
  $creditlink =~ s/end/credit_end/;
}
warn $creditlink;


</%init>
