<& /elements/header.html, "$agentname Tax Report: ".
  ( $beginning
      ? time2str('%h %o %Y ', $beginning )
      : ''
  ).
  'through '.
  ( $ending == 4294967295
      ? 'now'
      : time2str('%h %o %Y', $ending )
  ). ' - ' . $taxname
&>
<TD ALIGN="right">
Download full results<BR>
as <A HREF="<% $p.'search/report_tax-xls.cgi?'.$cgi->query_string%>">Excel spreadsheet</A>
</TD>

<STYLE type="text/css">
TD.sectionhead {
  background-color: #777777;
  color: #ffffff;
  font-weight: bold;
  text-align: left;
}
.grid TH { background-color: #cccccc; padding: 0px 3px 2px }
.row0 TD { background-color: #eeeeee; padding: 0px 3px 2px; text-align: right}
.row1 TD { background-color: #ffffff; padding: 0px 3px 2px; text-align: right}
TD.rowhead { font-weight: bold; text-align: left }
.bigmath { font-size: large; font-weight: bold; font: sans-serif; text-align: center }
</STYLE>
<& /elements/table-grid.html &>
  <TR>
    <TH ROWSPAN=3></TH>
    <TH COLSPAN=5>Sales</TH>
    <TH ROWSPAN=3></TH>
    <TH ROWSPAN=3>Rate</TH>
    <TH ROWSPAN=3></TH>
    <TH ROWSPAN=3>Estimated tax</TH>
    <TH ROWSPAN=3>Tax invoiced</TH>
    <TH ROWSPAN=3></TH>
    <TH ROWSPAN=3>Tax credited</TH>
    <TH ROWSPAN=3></TH>
    <TH ROWSPAN=3>Net tax due</TH>
  </TR>

  <TR>
    <TH ROWSPAN=2>Total</TH>
    <TH ROWSPAN=1>Non-taxable</TH>
    <TH ROWSPAN=1>Non-taxable</TH>
    <TH ROWSPAN=1>Non-taxable</TH>
    <TH ROWSPAN=2>Taxable</TH>
  </TR>

  <TR STYLE="font-size:small">
    <TH>(tax-exempt customer)</TH>
    <TH>(tax-exempt package)</TH>
    <TH>(monthly exemption)</TH>
  </TR>

% my $row = 0;
% my $classlink = '';
% my $descend;
% $descend = sub {
%   my ($data, $label) = @_;
%   if ( ref $data eq 'ARRAY' ) {
%     # then we've reached the bottom
%     my (%taxnums, %values);
%     foreach (@$data) {
%       $taxnums{ $_->[0] } = $_->[1];
%       $values{ $_->[0] } = $_->[2];
%     }
%     # finally, output
  <TR CLASS="row<% $row %>">
%     # Row label
    <TD CLASS="rowhead"><% $label |h %></TD>
%     # Total Sales
%     my $sales = $money_sprintf->(
%       $values{taxable} +
%       $values{exempt_cust} +
%       $values{exempt_pkg} +
%       $values{exempt_monthly}
%     );
%     my %sales_taxnums;
%     foreach my $x (qw(taxable exempt_cust exempt_pkg exempt_monthly)) {
%       foreach (split(',', $taxnums{$x})) {
%         $sales_taxnums{$_} = 1;
%       }
%     }
%     my $sales_taxnums = join(',', keys %sales_taxnums);
    <TD>
      <A HREF="<% "$saleslink;$classlink;taxnum=$sales_taxnums" %>">
        <% $sales %>
      </A>
    </TD>
%     # exemptions
%     foreach(qw(cust pkg)) {
    <TD>
      <A HREF="<% "$saleslink;$classlink;exempt_$_=Y;taxnum=".$taxnums{"exempt_$_"} %>">
        <% $money_sprintf->($values{"exempt_$_"}) %>
      </A>
    </TD>
%     }
    <TD>
      <A HREF="<% "$exemptlink;$classlink;taxnum=".$taxnums{"exempt_monthly"} %>">
        <% $money_sprintf->($values{"exempt_monthly"}) %>
      </A>
    </TD>
%     # taxable
    <TD>
      <A HREF="<% "$saleslink;$classlink;taxable=1;taxnum=$taxnums{taxable}" %>">
        <% $money_sprintf->($values{taxable}) %>
      </A>
    </TD>
%     # tax rate
%     my $rate;
%     foreach(split(',', $taxnums{tax})) {
%       $rate ||= $taxrates{$_};
%       if ($rate != $taxrates{$_}) {
%         $rate = 'variable';
%         last;
%       }
%     }
%     $rate = sprintf('%.2f', $rate) . '%' if ($rate and $rate ne 'variable');
    <TD CLASS="bigmath"> &times; </TD>
    <TD><% $rate %></TD>
%     # estimated tax
    <TD CLASS="bigmath"> = </TD>
    <TD><% $rate eq 'variable' 
            ? ''
            : $money_sprintf->( $values{taxable} * $rate / 100 ) %>
    </TD>
%     # invoiced tax
    <TD>
      <A HREF="<% "$taxlink;$classlink;taxnum=$taxnums{taxable}" %>">
        <% $money_sprintf->( $values{tax} ) %>
      </A>
    </TD>
%     # credited tax
    <TD CLASS="bigmath"> &minus; </TD>
    <TD>
      <A HREF="<% "$creditlink;$classlink;taxnum=$taxnums{credited}" %>">
        <% $money_sprintf->( $values{credited} ) %>
      </A>
    </TD>
%     # net tax due
    <TD CLASS="bigmath"> = </TD>
    <TD><% $money_sprintf->( $values{tax} - $values{credited} ) %></TD>
  </TR>

%     $row = $row ? 0 : 1;
%
%   } else { # we're not at the lowest classification
%     my @keys = sort { $a <=> $b or $a cmp $b } keys(%$data);
%     foreach my $key (@keys) {
%       my $sublabel = join(', ', grep $_, $label, $key);
%       &{ $descend }($data->{$key}, $sublabel);
%     }
%   }
% };

% my @pkgclasses = sort { $a <=> $b } keys %data;
% foreach my $pkgclass (@pkgclasses) {
%   my $class = FS::pkg_class->by_key($pkgclass) ||
%               FS::pkg_class->new({ classname => 'Unclassified' });
  <TBODY>
%   if ( $breakdown{pkgclass} ) {
  <TR>
    <TD COLSPAN=19 CLASS="sectionhead"><% $class->classname %></TD>
  </TR>
%   }
%   $row = 0;
%   $classlink = "classnum=".($pkgclass || 0) if $breakdown{pkgclass};
%   &{ $descend }( $data{$pkgclass}, '' );
%   # and now totals
  </TBODY>
  <TBODY CLASS="total">
%   &{ $descend }( $total{$pkgclass}, 'Total' );
  </TBODY>
% } # foreach $pkgclass
</TABLE>

<& /elements/footer.html &>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $DEBUG = $cgi->param('debug') || 0;

my $conf = new FS::Conf;

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

my ($taxname, $country, %breakdown);

if ( $cgi->param('taxname') =~ /^([\w\s]+)$/ ) {
  $taxname = $1;
} else {
  die "taxname required"; # UI prevents this
}

if ( $cgi->param('country') =~ /^(\w\w)$/ ) {
  $country = $1;
} else {
  die "country required";
}

# %breakdown: short name => field identifier
foreach ($cgi->param('breakdown')) {
  if ( $_ eq 'taxclass' ) {
    $breakdown{'taxclass'} = 'part_pkg.taxclass';
  } elsif ( $_ eq 'pkgclass' ) {
    $breakdown{'pkgclass'} = 'part_pkg.classnum';
  } elsif ( $_ eq 'city' ) {
    $breakdown{'city'} = 'cust_main_county.city';
    $breakdown{'district'} = 'cust_main_county.district';
  }
}
# always break these down
$breakdown{'state'} = 'cust_main_county.state';
$breakdown{'county'} = 'cust_main_county.county';

my $join_cust =     '      JOIN cust_bill     USING ( invnum  )
                      LEFT JOIN cust_main     USING ( custnum ) ';

my $join_cust_pkg = $join_cust.
                    ' LEFT JOIN cust_pkg      USING ( pkgnum  )
                      LEFT JOIN part_pkg      USING ( pkgpart ) ';

my $from_join_cust_pkg = " FROM cust_bill_pkg $join_cust_pkg "; 

# all queries MUST be linked to both cust_bill and cust_main_county

# either or both of these can be used to link cust_bill_pkg to cust_main_county
my $pkg_tax = "SELECT SUM(amount) as tax_amount, invnum, taxnum, ".
  "cust_bill_pkg_tax_location.pkgnum ".
  "FROM cust_bill_pkg_tax_location JOIN cust_bill_pkg USING (billpkgnum) ".
  "GROUP BY billpkgnum, invnum, taxnum, cust_bill_pkg_tax_location.pkgnum";

my $pkg_tax_exempt = "SELECT SUM(amount) AS exempt_charged, billpkgnum, taxnum ".
  "FROM cust_tax_exempt_pkg EXEMPT_WHERE GROUP BY billpkgnum, taxnum";

my $where = "WHERE _date >= $beginning AND _date <= $ending ".
            "AND COALESCE(cust_main_county.taxname,'Tax') = '$taxname' ".
            "AND cust_main_county.country = '$country'";
# SELECT/GROUP clauses for first-level queries
my $select = "SELECT ";
my $group = "GROUP BY ";
foreach (qw(pkgclass taxclass state county city district)) {
  if ( $breakdown{$_} ) {
    $select .= "$breakdown{$_} AS $_, ";
    $group  .= "$breakdown{$_}, ";
  } else {
    $select .= "NULL AS $_, ";
  }
}
$select .= "array_to_string(array_agg(DISTINCT(cust_main_county.taxnum)), ',') AS taxnums, ";
$group =~ s/, $//;

# SELECT/GROUP clauses for second-level (totals) queries
# breakdown by package class only, if anything
my $select_all = "SELECT NULL AS pkgclass, ";
my $group_all = "";
if ( $breakdown{pkgclass} ) {
  $select_all = "SELECT $breakdown{pkgclass} AS pkgclass, ";
  $group_all = "GROUP BY $breakdown{pkgclass}";
}
$select_all .= "array_to_string(array_agg(DISTINCT(cust_main_county.taxnum)), ',') AS taxnums, ";

my $agentname = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "agent not found" unless $agent;
  $agentname = $agent->agent;
  $where .= ' AND cust_main.agentnum = '. $agent->agentnum;
}

my $nottax = 'cust_bill_pkg.pkgnum != 0';

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
  $join_cust_pkg $where AND $nottax
  $group";

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
  JOIN cust_bill_pkg USING (invnum, pkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
    ON (pkg_tax_exempt.billpkgnum = cust_bill_pkg.billpkgnum 
        AND pkg_tax_exempt.taxnum = cust_main_county.taxnum)
  $join_cust_pkg $where AND $nottax 
  $group";

$all_sql{taxable} = "$select_all
  SUM(cust_bill_pkg.setup + cust_bill_pkg.recur - COALESCE(exempt_charged, 0))
  FROM cust_main_county
  JOIN ($pkg_tax) AS pkg_tax USING (taxnum)
  JOIN cust_bill_pkg USING (invnum, pkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
    ON (pkg_tax_exempt.billpkgnum = cust_bill_pkg.billpkgnum 
        AND pkg_tax_exempt.taxnum = cust_main_county.taxnum)
  $join_cust_pkg $where AND $nottax 
  $group_all";

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

if ( $breakdown{pkgclass} ) {
  # If we're not grouping by package class, this is unnecessary, and
  # probably really expensive.
  $taxfrom .= "
                LEFT JOIN cust_bill_pkg AS taxable
                  ON (cust_bill_pkg_tax_location.taxable_billpkgnum = taxable.billpkgnum)
                LEFT JOIN cust_pkg ON (taxable.pkgnum = cust_pkg.pkgnum)
                LEFT JOIN part_pkg USING (pkgpart)";
}

my $istax = "cust_bill_pkg.pkgnum = 0";

$sql{tax} = "$select SUM(cust_bill_pkg_tax_location.amount)
             $taxfrom
             $where AND $istax
             $group";

$all_sql{tax} = "$select_all SUM(cust_bill_pkg_tax_location.amount)
             $taxfrom
             $where AND $istax
             $group_all";

# sum of credits applied against billed tax
# ($creditfrom includes join of taxable item to part_pkg if with_pkgclass
# is on)
my $creditfrom = $taxfrom .
   ' JOIN cust_credit_bill_pkg USING (billpkgtaxlocationnum)';
my $creditwhere = $where . 
   ' AND billpkgtaxratelocationnum IS NULL';

$sql{credit} = "$select SUM(cust_credit_bill_pkg.amount)
                $creditfrom
                $creditwhere AND $istax
                $group";

$all_sql{credit} = "$select_all SUM(cust_credit_bill_pkg.amount)
                $creditfrom
                $creditwhere AND $istax
                $group_all";

my %data;
my %total;
my %taxclass_name = { '' => '' };
if ( $breakdown{taxclass} ) {
  $taxclass_name{$_->taxclassnum} = $_->taxclass
    foreach qsearch('tax_class');
  $taxclass_name{''} = 'Unclassified';
}
foreach my $k (keys(%sql)) {
  my $stmt = $sql{$k};
  warn "\n".uc($k).":\n".$stmt."\n" if $DEBUG;
  my $sth = dbh->prepare($stmt);
  # eight columns: pkgclass, taxclass, state, county, city, district
  # taxnums (comma separated), value
  # *sigh*
  $sth->execute 
    or die "failed to execute $k query: ".$sth->errstr;
  while ( my $row = $sth->fetchrow_arrayref ) {
    my $bin = $data
              {$row->[0]}
              {$taxclass_name{$row->[1]}}
              {$row->[2]}
              {$row->[3] ? $row->[3] . ' County' : ''}
              {$row->[4]}
              {$row->[5]}
            ||= [];
    push @$bin, [ $k, $row->[6], $row->[7] ];
  }
}
warn "DATA:\n".Dumper(\%data) if $DEBUG > 1;

foreach my $k (keys %all_sql) {
  warn "\nTOTAL ".uc($k).":\n".$all_sql{$k}."\n" if $DEBUG;
  my $sth = dbh->prepare($all_sql{$k});
  # three columns: pkgclass, taxnums (comma separated), value
  $sth->execute 
    or die "failed to execute $k totals query: ".$sth->errstr;
  while ( my $row = $sth->fetchrow_arrayref ) {
    my $bin = $total{$row->[0]} ||= [];
    push @$bin, [ $k, $row->[1], $row->[2] ];
  }
}
warn "TOTALS:\n".Dumper(\%total) if $DEBUG > 1;

# $data{$pkgclass}{$taxclass}{$state}{$county}{$city}{$district} = [
#   [ 'taxable',     taxnums, amount ],
#   [ 'exempt_cust', taxnums, amount ],
#   ...
# ]
# non-requested grouping levels simply collapse into key = ''

my $money_char = $conf->config('money_char') || '$';
my $money_sprintf = sub {
  $money_char. sprintf('%.2f', shift );
};

my $dateagentlink = "begin=$beginning;end=$ending";
$dateagentlink .= ';agentnum='. $cgi->param('agentnum')
  if length($agentname);
my $saleslink  = $p. "search/cust_bill_pkg.cgi?$dateagentlink;nottax=1";
my $taxlink    = $p. "search/cust_bill_pkg.cgi?$dateagentlink;istax=1";
my $exemptlink = $p. "search/cust_tax_exempt_pkg.cgi?$dateagentlink";
my $creditlink = $p. "search/cust_bill_pkg.cgi?$dateagentlink;credit=1;istax=1";

my %taxrates;
foreach my $tax (
  qsearch('cust_main_county', {
            country => $country,
            tax => { op => '>', value => 0 }
          }) )
  {
  $taxrates{$tax->taxnum} = $tax->tax;
}

</%init>
