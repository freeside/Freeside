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
    <TH CLASS="grid" BGCOLOR="#cccccc">Tax collected</TH>
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
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ALIGN="right">
        <A HREF="<% $baselink. $link %>;istax=1"><% $money_char %><% sprintf('%.2f', $tax->{'tax'} ) %></A>
      </TD>
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
my $from_join_cust = "
    FROM cust_bill_pkg
    $join_cust
"; 

my $where = "WHERE _date >= $beginning AND _date <= $ending ";

my $agentname = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = qsearchs('agent', { 'agentnum' => $1 } );
  die "agent not found" unless $agent;
  $agentname = $agent->agent;
  $where .= ' AND cust_main.agentnum = '. $agent->agentnum;
}

my $tax = 0;
my %taxes = ();
foreach my $t (qsearch({ table     => 'cust_bill_pkg',
                         hashref   => { pkgpart => 0 },
                         addl_from => $join_cust,
                         extra_sql => $where,
                      })
              )
{
  #warn $t->itemdesc. "\n";

  my $label = $t->itemdesc;
  $label ||= 'Tax';
  $taxes{$label}->{'label'} = $label;
  $taxes{$label}->{'url_param'} = "itemdesc=$label";

  # calculate total for this tax 
  # calculate customer-exemption for this tax
  # calculate package-exemption for this tax
  # calculate monthly exemption (texas tax) for this tax
  # count up all the cust_tax_exempt_pkg records associated with
  # the actual line items.
}


foreach my $t (qsearch({ table     => 'cust_bill_pkg',
                         select    => 'DISTINCT itemdesc',
                         hashref   => { pkgpart => 0 },
                         addl_from => $join_cust,
                         extra_sql => $where,
                      })
              )
{

  my $label = $t->itemdesc;
  $label ||= 'Tax';
  my @taxparam = ( 'itemdesc' );
  my $taxwhere = "$from_join_cust $where AND payby != 'COMP' ".
    "AND itemdesc = ?" ;

  my $sql = "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) ".
            " $taxwhere AND pkgnum = 0";

  my $x = scalar_sql($t, \@taxparam, $sql );
  $tax += $x;
  $taxes{$label}->{'tax'} += $x;

}

#ordering
my @taxes =
  map $taxes{$_},
  sort { ($b cmp $a) }
  keys %taxes;

push @taxes, {
  'label'          => 'Total',
  'url_param'      => '',
  'tax'            => $tax,
};

#-- 

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

my $dateagentlink = "begin=$beginning;end=$ending";
$dateagentlink .= ';agentnum='. $cgi->param('agentnum')
  if length($agentname);
my $baselink   = $p. "search/cust_bill_pkg.cgi?$dateagentlink";

</%init>
