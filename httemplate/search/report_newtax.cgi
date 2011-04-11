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

<% include('/elements/table-grid.html') %>

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Tax invoiced</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">&nbsp;&nbsp;&nbsp;&nbsp;</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Tax credited</TH>
  </TR>
% my $bgcolor1 = '#eeeeee';
% my $bgcolor2 = '#ffffff';
% my $bgcolor;
%
% foreach my $tax ( @taxes ) {
%
%   if ( $bgcolor eq $bgcolor1 ) {
%     $bgcolor = $bgcolor2;
%   } else {
%     $bgcolor = $bgcolor1;
%   }
%
%   my $link = '';
%   if ( $tax->{'label'} ne 'Total' ) {
%     $link = ';'. $tax->{'url_param'};
%   }
%

    <TR>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $tax->{'label'} %></TD>
      <% $tax->{base} ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ALIGN="right">
        <A HREF="<% $baselink. $link %>;istax=1"><% $money_char %><% sprintf('%.2f', $tax->{'tax'} ) %></A>
      </TD>
      <% !($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"></TD>
      <% $tax->{base} ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ALIGN="right">
        <A HREF="<% $baselink. $link %>;istax=1;iscredit=rate"><% $money_char %><% sprintf('%.2f', $tax->{'credit'} ) %></A>
      </TD>
      <% !($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
    </TR>
% } 

</TABLE>

</BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

my $join_cust = "
    JOIN cust_bill USING ( invnum ) 
    LEFT JOIN cust_main USING ( custnum )
";

my $join_loc = "LEFT JOIN cust_bill_pkg_tax_rate_location USING ( billpkgnum )";
my $join_tax_loc = "LEFT JOIN tax_rate_location USING ( taxratelocationnum )";

my $addl_from = " $join_cust $join_loc $join_tax_loc "; 

my $where = "WHERE _date >= $beginning AND _date <= $ending ";

my $agentname = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "agent not found" unless $agent;
  $agentname = $agent->agent;
  $where .= ' AND cust_main.agentnum = '. $agent->agentnum;
}

#my @taxparam = ( 'itemdesc', 'tax_rate_location.state', 'tax_rate_location.county', 'tax_rate_location.city', 'cust_bill_pkg_tax_rate_location.locationtaxid' );
my @taxparams = qw( city county state locationtaxid );
my @params = ('itemdesc', @taxparams);

my $select = 'DISTINCT itemdesc,locationtaxid,tax_rate_location.state,tax_rate_location.county,tax_rate_location.city';

my $tax = 0;
my $credit = 0;
my %taxes = ();
my %basetaxes = ();
foreach my $t (qsearch({ table     => 'cust_bill_pkg',
                         select    => $select,
                         hashref   => { pkgpart => 0 },
                         addl_from => $addl_from,
                         extra_sql => $where,
                      })
              )
{
  #my @params = map { my $f = $_; $f =~ s/.*\.//; $f } @taxparam;
  my $label = join('~', map { $t->$_ } @params);
  $label = 'Tax'. $label if $label =~ /^~/;
  unless ( exists( $taxes{$label} ) ) {
    my ($baselabel, @trash) = split /~/, $label;

    $taxes{$label}->{'label'} = join(', ', split(/~/, $label) );
    $taxes{$label}->{'url_param'} =
      join(';', map { "$_=". uri_escape($t->$_) } @params);

    my $taxwhere = "FROM cust_bill_pkg $addl_from $where AND payby != 'COMP' ".
      "AND ". FS::tax_rate_location->location_sql( map { $_ => $t->$_ }
                                                       @taxparams
                                                 );

    my $sql = "SELECT SUM(amount) $taxwhere AND cust_bill_pkg.pkgnum = 0";

    my $x = scalar_sql($t, [], $sql );
    $tax += $x;
    $taxes{$label}->{'tax'} += $x;

    my $creditfrom = " JOIN cust_credit_bill_pkg USING (billpkgnum,billpkgtaxratelocationnum) ";
    my $creditwhere = "FROM cust_bill_pkg $addl_from $creditfrom $where ".
      "AND payby != 'COMP' ".
      "AND ". FS::tax_rate_location->location_sql( map { $_ => $t->$_ }
                                                       @taxparams
                                                 );

    $sql = "SELECT SUM(cust_credit_bill_pkg.amount) ".
           " $creditwhere AND cust_bill_pkg.pkgnum = 0";

    my $y = scalar_sql($t, [], $sql );
    $credit += $y;
    $taxes{$label}->{'credit'} += $y;

    unless ( exists( $taxes{$baselabel} ) ) {

      $basetaxes{$baselabel}->{'label'} = $baselabel;
      $basetaxes{$baselabel}->{'url_param'} = "itemdesc=$baselabel";
      $basetaxes{$baselabel}->{'base'} = 1;

    }

    $basetaxes{$baselabel}->{'tax'} += $x;
    $basetaxes{$baselabel}->{'credit'} += $y;
      
  }

  # calculate customer-exemption for this tax
  # calculate package-exemption for this tax
  # calculate monthly exemption (texas tax) for this tax
  # count up all the cust_tax_exempt_pkg records associated with
  # the actual line items.
}


#ordering
my @taxes = ();

foreach my $tax ( sort { $a cmp $b } keys %taxes ) {
  my ($base, @trash) = split '~', $tax;
  my $basetax = delete( $basetaxes{$base} );
  if ($basetax) {
    if ( $basetax->{tax} == $taxes{$tax}->{tax} ) {
      $taxes{$tax}->{base} = 1;
    } else {
      push @taxes, $basetax;
    }
  }
  push @taxes, $taxes{$tax};
}

push @taxes, {
  'label'          => 'Total',
  'url_param'      => '',
  'tax'            => $tax,
  'credit'         => $credit,
  'base'           => 1,
};

#-- 

#false laziness w/FS::Report::Table::Monthly (sub should probably be moved up
#to FS::Report or FS::Record or who the fuck knows where)
sub scalar_sql {
  my( $r, $param, $sql ) = @_;
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( map $r->$_(), @$param )
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  $sth->fetchrow_arrayref->[0] || 0;
}

my $dateagentlink = "begin=$beginning;end=$ending";
$dateagentlink .= ';agentnum='. $cgi->param('agentnum')
  if length($agentname);
my $baselink   = $p. "search/cust_bill_pkg.cgi?$dateagentlink";

</%init>
