<% include( 'elements/search.html',
                 'title'       => 'Line items',
                 'name'        => 'line items',
                 'query'       => $query,
                 'count_query' => $count_query,
                 'count_addl'  => [ $money_char. '%.2f total', ],
                 'header'      => [
                   '#',
                   'Description',
                   'Setup charge',
                   'Recurring charge',
                   'Invoice',
                   'Date',
                   FS::UI::Web::cust_header(),
                 ],
                 'fields'      => [
                   'billpkgnum',
                   sub { $_[0]->pkgnum > 0
                           ? $_[0]->get('pkg')
                           : $_[0]->get('itemdesc')
                       },
                   #strikethrough or "N/A ($amount)" or something these when
                   # they're not applicable to pkg_tax search
                   sub { sprintf($money_char.'%.2f', shift->setup ) },
                   sub { sprintf($money_char.'%.2f', shift->recur ) },
                   'invnum',
                   sub { time2str('%b %d %Y', shift->_date ) },
                   \&FS::UI::Web::cust_fields,
                 ],
                 'links'       => [
                   '',
                   '',
                   '',
                   '',
                   $ilink,
                   $ilink,
                   ( map { $_ ne 'Cust. Status' ? $clink : '' }
                         FS::UI::Web::cust_header()
                   ),
                 ],
                 'align' => 'rlrrrc'.FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
           )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

#here is the agent virtualization
my $agentnums_sql =
  $FS::CurrentUser::CurrentUser->agentnums_sql( 'table' => 'cust_main' );

my @where = ( $agentnums_sql );

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
push @where, "_date >= $beginning",
             "_date <= $ending";

push @where , " payby != 'COMP' "
  unless $cgi->param('include_comp_cust');

if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  push @where, "cust_main.agentnum = $1";
}

if ( $cgi->param('classnum') =~ /^(\d+)$/ ) {
  if ( $1 == 0 ) {
    push @where, "classnum IS NULL";
  } else {
    push @where, "classnum = $1";
  }
}

if ( $cgi->param('out') ) {

  push @where, "
    0 = (
      SELECT COUNT(*) FROM cust_main_county
      WHERE (    cust_main_county.county  = cust_main.county
              OR ( cust_main_county.county IS NULL AND cust_main.county  =  '' )
              OR ( cust_main_county.county  =  ''  AND cust_main.county IS NULL)
              OR ( cust_main_county.county IS NULL AND cust_main.county IS NULL)
            )
        AND (    cust_main_county.state   = cust_main.state
              OR ( cust_main_county.state  IS NULL AND cust_main.state  =  ''  )
              OR ( cust_main_county.state   =  ''  AND cust_main.state IS NULL )
              OR ( cust_main_county.state  IS NULL AND cust_main.state IS NULL )
            )
        AND cust_main_county.country = cust_main.country
        AND cust_main_county.tax > 0
    )
  ";

} elsif ( $cgi->param('country' ) ) {

  my $county  = dbh->quote( $cgi->param('county')  );
  my $state   = dbh->quote( $cgi->param('state')   );
  my $country = dbh->quote( $cgi->param('country') );
  push @where, 
    " ( county  = $county OR $county = '' ) ",
    " ( state   = $state  OR $state  = '' ) ",
    "   country = $country "
  ;
  push @where, ' taxclass = '. dbh->quote( $cgi->param('taxclass') )
    if $cgi->param('taxclass');

  if ( $cgi->param('taxclassNULL') ) {
    my $same_sql = $r->sql_taxclass_sameregion;
    push @where, $same_sql if $same_sql;
  }

}

push @where, 'pkgnum != 0' if $cgi->param('nottax');
push @where, 'pkgnum  = 0' if $cgi->param('istax');

push @where, " tax = 'Y' " if $cgi->param('cust_tax');

my $count_query;
if ( $cgi->param('pkg_tax') ) {

  $count_query =
    "SELECT COUNT(*), SUM(
                           ( CASE WHEN part_pkg.setuptax = 'Y'
                                  THEN cust_bill_pkg.setup
                                  ELSE 0
                             END
                           )
                           +
                           ( CASE WHEN part_pkg.recurtax = 'Y'
                                  THEN cust_bill_pkg.recur
                                  ELSE 0
                             END
                           )
                         )
    ";

  push @where, "(    ( part_pkg.setuptax = 'Y' AND cust_bill_pkg.setup > 0 )
                  OR ( part_pkg.recurtax = 'Y' AND cust_bill_pkg.recur > 0 ) )",
               "( tax != 'Y' OR tax IS NULL )";

} else {

  $count_query =
    "SELECT COUNT(*), SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)";

}

my $where = ' WHERE '. join(' AND ', @where);

my $join_cust = "
    JOIN cust_bill USING ( invnum ) 
    LEFT JOIN cust_main USING ( custnum )
";

my $join_pkg = "
    LEFT JOIN cust_pkg USING ( pkgnum )
    LEFT JOIN part_pkg USING ( pkgpart )
";

$count_query .= " FROM cust_bill_pkg $join_cust $join_pkg $where";

my $query = {
  'table'     => 'cust_bill_pkg',
  'addl_from' => "$join_cust $join_pkg",
  'hashref'   => {},
  'select'    => join(', ',
                   'cust_bill_pkg.*',
                   'cust_bill._date',
                   'part_pkg.pkg',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $where,
  'order_by'  => 'ORDER BY _date, billpkgnum',
};

my $ilink = [ "${p}view/cust_bill.cgi?", 'invnum' ];
my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

</%init>
