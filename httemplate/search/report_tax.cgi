<!-- mason kludge -->
<%

my $user = getotaker;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
my $pbeginning = $1;
my $beginning = $1 ? str2time($1) : 0;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
my $pending = $1;
my $ending = ( $1 ? str2time($1) : 4294880896 ) + 86399;

my($total, $exempt, $taxable, $tax) = ( 0, 0, 0, 0 );
my $out = 'Out of taxable region(s)';
my %regions;
foreach my $r (
  qsearch('cust_main_county', {}, '',
          "WHERE 0 < ( SELECT COUNT(*) FROM cust_main
                       WHERE ( cust_main.county  = cust_main_county.county
                               OR cust_main_county.county = ''
                               OR cust_main_county.county IS NULL )
                         AND ( cust_main.state   = cust_main_county.state
                               OR cust_main_county.state = ''
                               OR cust_main_county.state IS NULL )
                         AND ( cust_main.country = cust_main_county.country )
                       LIMIT 1
                     )"
         )
) {
  #warn $r->county. ' '. $r->state. ' '. $r->country. "\n";
  my $label;
  if ( $r->tax == 0 ) {
    $label = $out;
  } elsif ( $r->taxname ) {
    $label = $r->taxname;
  } else {
    $label = $r->country;
    $label = $r->state.", $label" if $r->state;
    $label = $r->county." county, $label" if $r->county;
  }

  my $fromwhere = "
    FROM cust_bill_pkg
      JOIN cust_bill USING ( invnum ) 
      JOIN cust_main USING ( custnum )
      JOIN cust_pkg USING ( pkgnum )
      JOIN part_pkg USING ( pkgpart )
    WHERE _date >= $beginning AND _date <= $ending
      AND ( county  = ? OR ? = '' )
      AND ( state   = ? OR ? = '' )
      AND ( country = ? )
      AND ( taxclass = ? OR ? = '' )
      AND payby != 'COMP'
  ";
  my $nottax = 'pkgnum != 0';

  my $a = scalar_sql($r,
    "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) $fromwhere AND $nottax"
  );
  $total += $a;
  $regions{$label}->{'total'} += $a;

  foreach my $e ( grep { $r->get($_.'tax') =~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    my $x = scalar_sql($r,
      "SELECT SUM($e) $fromwhere AND $nottax"
    );
    $exempt += $x;
    $regions{$label}->{'exempt'} += $x;
  }

  foreach my $e ( grep { $r->get($_.'tax') !~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    my $t = scalar_sql($r,
      "SELECT SUM($e) $fromwhere AND $nottax AND ( tax != 'Y' OR tax IS NULL )"
    );
    $taxable += $t;
    $regions{$label}->{'taxable'} += $t;

    my $x = scalar_sql($r,
      "SELECT SUM($e) $fromwhere AND $nottax AND tax = 'Y'"
    );
    $exempt += $x;
    $regions{$label}->{'exempt'} += $x;
  }

  if ( defined($regions{$label}->{'rate'})
       && $regions{$label}->{'rate'} != $r->tax.'%' ) {
    $regions{$label}->{'rate'} = 'variable';
  } else {
    $regions{$label}->{'rate'} = $r->tax.'%';
  }

  #match itemdesc if necessary!
  my $named_tax = $r->taxname ? 'AND itemdesc = '. dbh->quote($r->taxname) : '';
  my $x = scalar_sql($r,
    "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) $fromwhere ".
    "AND pkgnum = 0 $named_tax",
  );
  $tax += $x;
  $regions{$label}->{'tax'} += $x;

  $regions{$label}->{'label'} = $label;

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
  'tax'       => $tax,
};

#-- 

#false laziness w/FS::Report::Table::Monthly (sub should probably be moved up
#to FS::Report or FS::Record or who the fuck knows where)
sub scalar_sql {
  my( $r, $sql ) = @_;
  #warn "$sql\n";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( map $r->$_(),
                     qw( county county state state country taxclass taxclass ) )
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
    <TH ROWSPAN=2>Tax</TH>
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
      <TD ALIGN="right">$<%= sprintf('%.2f', $region->{'tax'} ) %></TD>
    </TR>
  <% } %>

</TABLE>

</BODY>
</HTML>


