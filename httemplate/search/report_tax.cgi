<!-- mason kludge -->
<%

my $user = getotaker;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
my $pbeginning = $1;
my $beginning = str2time($1) || 0;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
my $pending = $1;
my $ending = ( str2time($1) || 4294880896 ) + 86399;

my($total, $exempt, $taxable, $tax) = ( 0, 0, 0, 0 );
my $out = 'Out of taxable region(s)';
my %regions;
foreach my $r ( qsearch('cust_main_county', {}) ) {
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

  #match taxclass too?

  my $fromwhere = "
    FROM cust_bill_pkg
      JOIN cust_bill USING ( invnum ) 
      JOIN cust_main USING ( custnum )
    WHERE _date >= $beginning AND _date <= $ending
      AND ( county  = ? OR ( ? = '' AND county  IS NULL ) )
      AND ( state   = ? OR ( ? = '' AND state   IS NULL ) )
      AND ( country = ? OR ( ? = '' AND country IS NULL ) )
  ";
  my $nottax = 'pkgnum != 0';

  my $a = scalar_sql($r,
    "SELECT SUM(setup+recur) $fromwhere AND $nottax"
  );
  $total += $a;
  $regions{$label}->{'total'} += $a;

  foreach my $e ( grep { $r->get($_.'tax') =~ /^Y/i } qw( setup recur ) ) {
    my $x = scalar_sql($r,
      "SELECT SUM($e) $fromwhere AND $nottax"
    );
    $exempt += $x;
    $regions{$label}->{'exempt'} += $x;
  }

  foreach my $e ( grep { $r->get($_.'tax') !~ /^Y/i } qw( setup recur ) ) {
    my $x = scalar_sql($r,
      "SELECT SUM($e) $fromwhere AND $nottax"
    );
    $taxable += $x;
    $regions{$label}->{'taxable'} += $x;
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
    "SELECT SUM(setup+recur) $fromwhere AND pkgnum = 0 $named_tax",
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
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( map $r->$_(), map { $_, $_ } qw( county state country ) )
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


