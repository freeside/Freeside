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

% my $bgcolor1 = '#eeeeee';
% my $bgcolor2 = '#ffffff';
% my $bgcolor;
%
% foreach my $region ( @regions ) {
%
%   my $link = '';
%   if ( $region->{'label'} eq $out ) {
%     $link = ';out=1';
%   } elsif ( $region->{'taxnums'} ) {
%     # might be nicer to specify this as country:state:city
%     $link = ';'.join(';', map { "taxnum=$_" } @{ $region->{'taxnums'} });
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

    <TR>
      <<%$td%>><% $region->{'label'} %></TD>
      <<%$td%> ALIGN="right">
        <A HREF="<% $baselink. $link %>;nottax=1"
        ><% &$money_sprintf( $region->{'sales'} ) %></A>
      </TD>
%     if ( $region->{'label'} eq $out ) {
      <<%$td%> COLSPAN=12></TD>
%     } else { #not $out
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
%       my $invlink = $region->{'url_param_inv'}
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
%   }
% } # not $out

    </TR>
% } 

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
%   $bgcolor1 = '#eeeeee';
%   $bgcolor2 = '#ffffff';
%
%   foreach my $region ( @base_regions ) {
%
%     my $link = '';
%     if ( $region->{'label'} eq $out ) {
%       $link = ';out=1';
%     } else {
%       $link = ';'. $region->{'url_param'}
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
$label_opt{no_city} = 1     unless $cgi->param('show_cities');
$label_opt{no_taxclass} = 1 unless $cgi->param('show_taxclasses');

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

my $join_cust =     '     JOIN cust_bill      USING ( invnum  ) 
                      LEFT JOIN cust_main     USING ( custnum ) ';

my $join_cust_pkg = $join_cust.
                    ' LEFT JOIN cust_pkg      USING ( pkgnum  )
                      LEFT JOIN part_pkg      USING ( pkgpart ) ';

my $from_join_cust_pkg = " FROM cust_bill_pkg $join_cust_pkg "; 

# either or both of these can be used to link cust_bill_pkg to cust_main_county
my $pkg_tax = "SELECT SUM(amount) as tax_amount, invnum, taxnum, ".
  "cust_bill_pkg_tax_location.pkgnum ".
  "FROM cust_bill_pkg_tax_location JOIN cust_bill_pkg USING (billpkgnum) ".
  "GROUP BY billpkgnum, invnum, taxnum, cust_bill_pkg_tax_location.pkgnum";

my $pkg_tax_exempt = "SELECT SUM(amount) AS exempt_charged, billpkgnum, taxnum ".
  "FROM cust_tax_exempt_pkg EXEMPT_WHERE GROUP BY billpkgnum, taxnum";

my $where = "WHERE _date >= $beginning AND _date <= $ending ";
my $group = "GROUP BY cust_main_county.taxnum";

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

# general form
my $exempt = "SELECT cust_main_county.taxnum, SUM(exempt_charged)
  FROM cust_main_county
  JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
  USING (taxnum)
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust $where AND $nottax $group";

my $all_exempt = "SELECT SUM(exempt_charged)
  FROM cust_main_county
  JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
  USING (taxnum)
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust $where AND $nottax";

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
$sql{taxable} = "SELECT cust_main_county.taxnum, 
  SUM(cust_bill_pkg.setup + cust_bill_pkg.recur - COALESCE(exempt_charged, 0))
  FROM cust_main_county
  JOIN ($pkg_tax) AS pkg_tax USING (taxnum)
  JOIN cust_bill_pkg USING (invnum, pkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt
    ON (pkg_tax_exempt.billpkgnum = cust_bill_pkg.billpkgnum 
        AND pkg_tax_exempt.taxnum = cust_main_county.taxnum)
  $join_cust $where AND $nottax $group";

# Here we're going to sum all line items that are taxable _at all_,
# under any tax.  exempt_charged is the sum of all exemptions for a 
# particular billpkgnum + taxnum; we take the taxnum that has the 
# smallest sum of exemptions and subtract that from the charged amount.
$all_sql{taxable} = "SELECT
  SUM(cust_bill_pkg.setup + cust_bill_pkg.recur - COALESCE(min_exempt, 0))
  FROM cust_bill_pkg
  JOIN (
    SELECT invnum, pkgnum, MIN(exempt_charged) AS min_exempt
    FROM ($pkg_tax) AS pkg_tax
    JOIN cust_bill_pkg USING (invnum, pkgnum)
    LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt USING (billpkgnum, taxnum)
    GROUP BY invnum, pkgnum
  ) AS pkg_is_taxable 
  USING (invnum, pkgnum)
  $join_cust $where AND $nottax";
  # we don't join pkg_tax_exempt.taxnum here, because

$sql{taxable} =~ s/EXEMPT_WHERE//; # unrestricted
$all_sql{taxable} =~ s/EXEMPT_WHERE//;

# there isn't one for 'sales', because we calculate sales by adding up 
# the taxable and exempt columns.

# sum of billed tax:
# join cust_bill_pkg to cust_main_county via cust_bill_pkg_tax_location
my $taxfrom = " FROM cust_bill_pkg 
                $join_cust 
                LEFT JOIN cust_bill_pkg_tax_location USING ( billpkgnum )
                LEFT JOIN cust_main_county USING ( taxnum )";

my $istax = "cust_bill_pkg.pkgnum = 0";
my $named_tax = "(
  taxname = itemdesc
  OR ( taxname IS NULL 
    AND ( itemdesc IS NULL OR itemdesc = '' OR itemdesc = 'Tax' )
  )
)";

$sql{tax} = "SELECT cust_main_county.taxnum, 
             SUM(cust_bill_pkg_tax_location.amount)
             $taxfrom
             $where AND $istax AND $named_tax
             $group";

$all_sql{tax} = "SELECT SUM(cust_bill_pkg.setup)
             FROM cust_bill_pkg
             $join_cust
             $where AND $istax";

# sum of credits applied against billed tax
my $creditfrom = $taxfrom .
   ' JOIN cust_credit_bill_pkg USING (billpkgtaxlocationnum)';
my $creditfromwhere = $where . 
   ' AND billpkgtaxratelocationnum IS NULL';

$sql{credit} = "SELECT cust_main_county.taxnum,
                SUM(cust_credit_bill_pkg.amount)
                $creditfrom
                $creditfromwhere AND $istax AND $named_tax
                $group";

$all_sql{credit} = "SELECT SUM(cust_credit_bill_pkg.amount)
                FROM cust_credit_bill_pkg
                JOIN cust_bill_pkg USING (billpkgnum)
                $join_cust
                $where AND $istax";

my %data;
my %total = (owed => 0);
foreach my $k (keys(%sql)) {
  my $stmt = $sql{$k};
  warn "\n".uc($k).":\n".$stmt."\n" if $DEBUG;
  my $sth = dbh->prepare($stmt);
  # two columns => key/value
  $sth->execute 
    or die "failed to execute $k query: ".$sth->errstr;
  $data{$k} = +{ map { @$_ } @{ $sth->fetchall_arrayref([]) } };

  warn "\n".$all_sql{$k}."\n" if $DEBUG;
  $total{$k} = FS::Record->scalar_sql( $all_sql{$k} );
  warn Dumper($data{$k}) if $DEBUG > 1;
}
# so $data{tax}, for example, is now a hash with one entry
# for each taxnum, containing the tax billed on that taxnum.

# oddball cases:
# "out of taxable region" sales
my %out;
my $out_sales_sql = 
  "SELECT SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)
  FROM (cust_bill_pkg $join_cust)
  LEFT JOIN ($pkg_tax) AS pkg_tax USING (invnum, pkgnum)
  LEFT JOIN ($pkg_tax_exempt) AS pkg_tax_exempt USING (billpkgnum)
  $where AND $nottax
  AND pkg_tax.taxnum IS NULL AND pkg_tax_exempt.taxnum IS NULL"
;

$out_sales_sql =~ s/EXEMPT_WHERE//;

$out{sales} = FS::Record->scalar_sql($out_sales_sql);

# unlinked tax collected (for diagnostics)
my $out_tax_sql =
  "SELECT SUM(cust_bill_pkg.setup)
  FROM (cust_bill_pkg $join_cust)
  LEFT JOIN cust_bill_pkg_tax_location USING (billpkgnum)
  $where AND $istax AND cust_bill_pkg_tax_location.billpkgnum IS NULL"
;
$out{tax} = FS::Record->scalar_sql($out_tax_sql);
# unlinked tax credited (for diagnostics)
my $out_credit_sql =
  "SELECT SUM(cust_credit_bill_pkg.amount)
  FROM cust_credit_bill_pkg
  JOIN cust_bill_pkg USING (billpkgnum)
  $join_cust
  $where AND $istax AND cust_credit_bill_pkg.billpkgtaxlocationnum IS NULL"
;
$out{credit} = FS::Record->scalar_sql($out_credit_sql);

# all sales
$total{sales} = FS::Record->scalar_sql(
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

# if show_taxclasses is on, %base_regions will contain the same data
# as %regions, but with taxclasses merged together (and ignoring report_group
# filtering).
my (%regions, %base_regions);
my $tot_tax = 0;
my $tot_credit = 0;

my @loc_params = qw(country state county);
push @loc_params, qw(city district) if $cgi->param('show_cities');

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
    next unless exists($data{$k}->{$taxnum});
    $x{$k} = $data{$k}->{$taxnum};
    $regions{$label}->{$k} += $x{$k};
    if ( $k eq 'taxable' or $k =~ /^exempt/ ) {
      $regions{$label}->{'sales'} += $x{$k};
    }
  }

  my $owed = $data{'taxable'}->{$taxnum} * ($r->tax/100);
  $regions{$label}->{'owed'} += $owed;
  $total{'owed'} += $owed;

  if ( defined($regions{$label}->{'rate'})
       && $regions{$label}->{'rate'} != $r->tax.'%' ) {
    $regions{$label}->{'rate'} = 'variable';
  } else {
    $regions{$label}->{'rate'} = $r->tax.'%';
  }

  if ( $cgi->param('show_taxclasses') ) {
    my $base_label = $r->label(%label_opt, 'no_taxclass' => 1);
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
%out = ( %out,
  'label' => $out,
  'rate' => ''
);
%total = ( %total, 
  'label'         => 'Total',
  'url_param'     => $total_url_param,
  'url_param_inv' => $total_url_param_invoiced,
  'rate'          => '',
);
push @regions, \%out, \%total;
push @base_regions, \%out, \%total;

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
my $creditlink = $p. "search/cust_bill_pkg.cgi?$dateagentlink;credit=1";

</%init>
