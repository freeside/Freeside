<!-- mason kludge -->
<%

my $user = getotaker;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
my $pbeginning = $1;
my $beginning = $1 ? str2time($1) : 0;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
my $pending = $1;
my $ending = ( $1 ? str2time($1) : 4294880896 ) + 86399;

my $from_join_cust = "
  FROM cust_bill_pkg
    JOIN cust_bill USING ( invnum ) 
    JOIN cust_main USING ( custnum )
";
my $join_pkg = "
    JOIN cust_pkg USING ( pkgnum )
    JOIN part_pkg USING ( pkgpart )
";
my $where = "
  WHERE _date >= $beginning AND _date <= $ending
    AND ( county  = ? OR ? = '' )
    AND ( state   = ? OR ? = '' )
    AND ( country = ? )
    AND payby != 'COMP'
";
my @base_param = qw( county county state state country );

my $gotcust = "
  WHERE 0 < ( SELECT COUNT(*) FROM cust_main
              WHERE ( cust_main.county  = cust_main_county.county
                      OR cust_main_county.county = ''
                      OR cust_main_county.county IS NULL )
                AND ( cust_main.state   = cust_main_county.state
                      OR cust_main_county.state = ''
                      OR cust_main_county.state IS NULL )
                AND ( cust_main.country = cust_main_county.country )
              LIMIT 1
            )
";

my $monthly_exempt_warning = 0;
my($total, $exempt, $taxable, $owed, $tax) = ( 0, 0, 0, 0, 0 );
my $out = 'Out of taxable region(s)';
my %regions;
foreach my $r (qsearch('cust_main_county', {}, '', $gotcust) ) {
  #warn $r->county. ' '. $r->state. ' '. $r->country. "\n";

  my $label = getlabel($r);
  $regions{$label}->{'label'} = $label;

  my $fromwhere = $from_join_cust. $join_pkg. $where;
  my @param = @base_param; 

  if ( $r->taxclass ) {
    $fromwhere .= " AND ( taxclass = ?  ) ";
    push @param, 'taxclass';
  }

  my $nottax = 'pkgnum != 0';

  my $a = scalar_sql($r, \@param,
    "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) $fromwhere AND $nottax"
  );
  $total += $a;
  $regions{$label}->{'total'} += $a;

  foreach my $e ( grep { $r->get($_.'tax') =~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    my $x = scalar_sql($r, \@param,
      "SELECT SUM($e) $fromwhere AND $nottax"
    );
    $exempt += $x;
    $regions{$label}->{'exempt'} += $x;
  }

  my($t, $x) = (0, 0);
  foreach my $e ( grep { $r->get($_.'tax') !~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    $t += scalar_sql($r, \@param, 
      "SELECT SUM($e) $fromwhere AND $nottax AND ( tax != 'Y' OR tax IS NULL )"
    );

    $x += scalar_sql($r, \@param, 
      "SELECT SUM($e) $fromwhere AND $nottax AND tax = 'Y'"
    );
  }

  my($sday,$smon,$syear) = (localtime($beginning) )[ 3, 4, 5 ];
  $monthly_exempt_warning=1 if $sday != 1 && $beginning;
  $smon++; $syear+=1900;

  my $eending = ( $ending == 4294967295 ) ? time : $ending;
  my($eday,$emon,$eyear) = (localtime($eending) )[ 3, 4, 5 ];
  $emon++; $eyear+=1900;

  my $monthly_exemption = scalar_sql($r, [ 'taxnum' ],
    "SELECT SUM(amount) FROM cust_tax_exempt where taxnum = ? ".
    "  AND ( year > $syear OR ( year = $syear and month >= $smon ) )".
    "  AND ( year < $eyear OR ( year = $eyear and month <= $emon ) )"
  );
  #warn $r->taxnum(). ": $monthly_exemption\n";
  if ( $monthly_exemption ) {
    $t -= $monthly_exemption;
    $x += $monthly_exemption;
  }

  $taxable += $t;
  $regions{$label}->{'taxable'} += $t;

  $exempt += $x;
  $regions{$label}->{'exempt'} += $x;

  $owed += $t * ($r->tax/100);
  $regions{$label}->{'owed'} += $t * ($r->tax/100);

  if ( defined($regions{$label}->{'rate'})
       && $regions{$label}->{'rate'} != $r->tax.'%' ) {
    $regions{$label}->{'rate'} = 'variable';
  } else {
    $regions{$label}->{'rate'} = $r->tax.'%';
  }

}

my $taxwhere = "$from_join_cust $where";
my @taxparam = @base_param;

#foreach my $label ( keys %regions ) {
foreach my $r (
  qsearch( 'cust_main_county',
           {},
           'DISTINCT ON (country, state, county, taxname) *',
           $gotcust
         )
) {

  #warn join('-', map { $r->$_() } qw( country state county taxname ) )."\n";

  my $label = getlabel($r);

  my $fromwhere = $join_pkg. $where;
  my @param = @base_param; 

  #match itemdesc if necessary!
  my $named_tax =
    $r->taxname
      ? 'AND itemdesc = '. dbh->quote($r->taxname)
      : "AND ( itemdesc IS NULL OR itemdesc = '' OR itemdesc = 'Tax' )";
  my $x = scalar_sql($r, \@taxparam,
    "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) $taxwhere ".
    "AND pkgnum = 0 $named_tax",
  );
  $tax += $x;
  $regions{$label}->{'tax'} += $x;

}

#ordering
my @regions = map $regions{$_},
              sort { ( ($a eq $out) cmp ($b eq $out) ) || ($b cmp $a) }
              keys %regions;

push @regions, {
  'label'     => 'Total',
  'total'     => $total,
  'exempt'    => $exempt,
  'taxable'   => $taxable,
  'rate'      => '',
  'owed'      => $owed,
  'tax'       => $tax,
};

#-- 

sub getlabel {
  my $r = shift;

  my $label;
  if ( $r->tax == 0 ) {
    #kludge to avoid "will not stay shared" warning
    my $out = 'Out of taxable region(s)';
    $label = $out;
  } elsif ( $r->taxname ) {
    $label = $r->taxname;
#    $regions{$label}->{'taxname'} = $label;
#    push @{$regions{$label}->{$_}}, $r->$_() foreach qw( county state country );
  } else {
    $label = $r->country;
    $label = $r->state.", $label" if $r->state;
    $label = $r->county." county, $label" if $r->county;
    #$label = $r->taxname. " ($label)" if $r->taxname;
  }
  return $label;
}

#false laziness w/FS::Report::Table::Monthly (sub should probably be moved up
#to FS::Report or FS::Record or who the fuck knows where)
sub scalar_sql {
  my( $r, $param, $sql ) = @_;
  #warn "$sql\n";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( map $r->$_(), @$param )
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  $sth->fetchrow_arrayref->[0] || 0;
}

%>

<%= header( "Sales Tax Report - $pbeginning through ".($pending||'now'),
            menubar( 'Main Menu'=>$p, ) )               %>
<%= table() %>
  <TR>
    <TH ROWSPAN=2></TH>
    <TH COLSPAN=3>Sales</TH>
    <TH ROWSPAN=2>Rate</TH>
    <TH ROWSPAN=2>Tax owed</TH>
    <TH ROWSPAN=2>Tax invoiced</TH>
  </TR>
  <TR>
    <TH>Total</TH>
    <TH>Non-taxable</TH>
    <TH>Taxable</TH>
  </TR>
  <% foreach my $region ( @regions ) { %>
    <TR>
      <TD><%= $region->{'label'} %></TD>
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'total'} ) %></TD>
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'exempt'} ) %></TD>
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'taxable'} ) %></TD>
      <TD ALIGN="right"><%= $region->{'rate'} %></TD>
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'owed'} ) %></TD>
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'tax'} ) %></TD>
    </TR>
  <% } %>

</TABLE>

<% if ( $monthly_exempt_warning ) { %>
  <BR>
  Partial-month tax reports (except for current month) may not be correct due
  to month-granularity tax exemption (usually "texas tax").  For an accurate
  report, start on the first of a month and end on the last day of a month (or
  leave blank for to now).
<% } %>

</BODY>
</HTML>


