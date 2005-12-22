<%

my $user = getotaker;

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

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
    AND   country = ?
    AND payby != 'COMP'
";
my @base_param = qw( county county state state country );

my $agentname = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "agent not found" unless $agent;
  $agentname = $agent->agent;
  $where .= ' AND agentnum = '. $agent->agentnum;
}

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
my($total, $taxable, $owed, $tax) = ( 0, 0, 0, 0, 0 );
my( $exempt_cust, $exempt_pkg, $exempt_monthly ) = ( 0, 0 );
my $out = 'Out of taxable region(s)';
my %regions = ();
foreach my $r (qsearch('cust_main_county', {}, '', $gotcust) ) {
  #warn $r->county. ' '. $r->state. ' '. $r->country. "\n";

  my $label = getlabel($r);
  $regions{$label}->{'label'} = $label;

  $regions{$label}->{'url_param'} = join(';', map "$_=".$r->$_(), qw( county state country ) );

  my $fromwhere = $from_join_cust. $join_pkg. $where;
  my @param = @base_param;

  if ( $r->taxclass ) {
    $fromwhere .= " AND taxclass = ? ";
    push @param, 'taxclass';
    $regions{$label}->{'url_param'} .= ';taxclass='. $r->taxclass;
  }

#  my $label = getlabel($r);
#  $regions{$label}->{'label'} = $label;

  my $nottax = 'pkgnum != 0';

  ## calculate total for this region

  my $t = scalar_sql($r, \@param,
    "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) $fromwhere AND $nottax"
  );
  $total += $t;
  $regions{$label}->{'total'} += $t;

  ## calculate package-exemption for this region

  foreach my $e ( grep { $r->get($_.'tax') =~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    my $x = scalar_sql($r, \@param,
      "SELECT SUM($e) $fromwhere AND $nottax"
    );
    $exempt_pkg += $x;
    $regions{$label}->{'exempt_pkg'} += $x;
  }

  ## calculate customer-exemption for this region

  my($t, $x_cust) = (0, 0);
  foreach my $e ( grep { $r->get($_.'tax') !~ /^Y/i }
                       qw( cust_bill_pkg.setup cust_bill_pkg.recur ) ) {
    $t += scalar_sql($r, \@param, 
      "SELECT SUM($e) $fromwhere AND $nottax AND ( tax != 'Y' OR tax IS NULL )"
    );

    $x_cust += scalar_sql($r, \@param, 
      "SELECT SUM($e) $fromwhere AND $nottax AND tax = 'Y'"
    );
  }

  $exempt_cust += $x_cust;
  $regions{$label}->{'exempt_cust'} += $x_cust;

  ## calculate monthly exemption (texas tax) for this region

  my($sday,$smon,$syear) = (localtime($beginning) )[ 3, 4, 5 ];
  $monthly_exempt_warning=1 if $sday != 1 && $beginning;
  $smon++; $syear+=1900;

  my $eending = ( $ending == 4294967295 ) ? time : $ending;
  my($eday,$emon,$eyear) = (localtime($eending) )[ 3, 4, 5 ];
  $emon++; $eyear+=1900;

  my $x_monthly = scalar_sql($r, [ 'taxnum' ],
    "SELECT SUM(amount) FROM cust_tax_exempt where taxnum = ? ".
    "  AND ( year > $syear OR ( year = $syear and month >= $smon ) )".
    "  AND ( year < $eyear OR ( year = $eyear and month <= $emon ) )"
  );
  if ( $x_monthly ) {
    warn $r->taxnum(). ": $x_monthly\n";
    $t -= $x_monthly;
  }

  $exempt_monthly += $x_monthly;
  $regions{$label}->{'exempt_monthly'} += $x_monthly;

  $taxable += $t;
  $regions{$label}->{'taxable'} += $t;

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
  'label'          => 'Total',
  'url_param'      => '',
  'total'          => $total,
  'exempt_cust'    => $exempt_cust,
  'exempt_pkg'     => $exempt_pkg,
  'exempt_monthly' => $exempt_monthly,
  'taxable'        => $taxable,
  'rate'           => '',
  'owed'           => $owed,
  'tax'            => $tax,
};

#-- 

sub getlabel {
  my $r = shift;

  my $label;
  if (
    $r->tax == 0 
    && ! scalar( qsearch('cust_main_county', { 'state'   => $r->state,
                                               'county'  => $r->county,
                                               'country' => $r->country,
                                               'tax' => { op=>'>', value=>0 },
                                             }
                        )
               )

  ) {
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
    $label = "$label (". $r->taxclass. ")" if $r->taxclass;
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

<%

my $baselink = $p. "search/cust_bill_pkg.cgi?begin=$beginning;end=$ending";

%>


<%= header( "$agentname Sales Tax Report - ".
              time2str('%h %o %Y through ', $beginning ).
              ( $cgi->param('ending') == 4294967295
                  ? 'now'
                  : time2str('%h %o %Y', $ending )
              ),
            menubar( 'Main Menu'=>$p, )
          )
%>

<%= include('/elements/table-grid.html') %>

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc"ROWSPAN=2></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"COLSPAN=5>Sales</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"ROWSPAN=2>Rate</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"ROWSPAN=2>Tax owed</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"ROWSPAN=2>Tax invoiced</TH>
  </TR>
  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc">Total</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Non-taxable<BR><FONT SIZE=-1>(tax-exempt customer)</FONT></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Non-taxable<BR><FONT SIZE=-1>(tax-exempt package)</FONT></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Non-taxable<BR><FONT SIZE=-1>(monthly exemption)</FONT></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Taxable</TH>
  </TR>

<% my $bgcolor1 = '#eeeeee';
   my $bgcolor2 = '#ffffff';
   my $bgcolor;
%>

  <% foreach my $region ( @regions ) {

       if ( $bgcolor eq $bgcolor1 ) {
         $bgcolor = $bgcolor2;
       } else {
         $bgcolor = $bgcolor1;
       }

       my $link = $baselink;
       if ( $region->{'label'} ne 'Total' ) {
         if ( $region->{'label'} eq $out ) {
           $link .= ';out=1';
         } else {
           $link .= ';'. $region->{'url_param'};
         }
       }
  %>
    <TR>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>"><%= $region->{'label'} %></TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        <A HREF="<%= $link %>;nottax=1">$<%= sprintf('%.2f', $region->{'total'} ) %></A>
      </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        <A HREF="<%= $link %>;nottax=1;cust_tax=Y">$<%= sprintf('%.2f', $region->{'exempt_cust'} ) %></A>
      </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        <A HREF="<%= $link %>;nottax=1;pkg_tax=Y">$<%= sprintf('%.2f', $region->{'exempt_pkg'} ) %></A>
      </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        $<%= sprintf('%.2f', $region->{'exempt_monthly'} ) %></A>
        </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        $<%= sprintf('%.2f', $region->{'taxable'} ) %></A>
      </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right"><%= $region->{'rate'} %></TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        $<%= sprintf('%.2f', $region->{'owed'} ) %>
      </TD>
      <TD CLASS="grid" BGCOLOR="<%= $bgcolor %>" ALIGN="right">
        <A HREF="<%= $link %>;istax=1">$<%= sprintf('%.2f', $region->{'tax'} ) %></A>
      </TD>
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


