<% include( 'elements/search.html',
                 'title'       => 'Legacy tax exemptions',
                 'name'        => 'legacy tax exemptions',
                 'query'       => $query,
                 'count_query' => $count_query,
                 'count_addl'  => [ $money_char. '%.2f total', ],
                 'header'      => [
                   '#',
                   'Month',
                   'Inserted',
                   'Amount',
                   FS::UI::Web::cust_header(),
                 ],
                 'fields'      => [
                   'exemptnum',
                   sub { $_[0]->month. '/'. $_[0]->year; },
                   sub { my $h = $_[0]->h_search('insert');
                         $h ? time2str('%L/%d/%Y', $h->history_date ) : ''
                       },
                   sub { $money_char. $_[0]->amount; },

                   \&FS::UI::Web::cust_fields,
                 ],
                 'links'       => [
                   '',
                   '',
                   '',
                   '',

                   ( map { $_ ne 'Cust. Status' ? $clink : '' }
                         FS::UI::Web::cust_header()
                   ),
                 ],
                 'align' => 'rrrr'.FS::UI::Web::cust_aligns(),
                 'color' => [ 
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
                              FS::UI::Web::cust_styles(),
                            ],
           )
%>
<%init>

my $join_cust = "
    LEFT JOIN cust_main USING ( custnum )
";

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer tax exemptions');

my @where = ();

#my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
#if ( $beginning || $ending ) {
#  push @where, "_date >= $beginning",
#               "_date <= $ending";
#               #"payby != 'COMP';
#}

if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  push @where, "agentnum = $1";
}

if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  push @where,  "cust_main.custnum = $1";
}

#prospect active inactive suspended cancelled
if ( grep { $cgi->param('status') eq $_ } FS::cust_main->statuses() ) {
  my $method = $cgi->param('status'). '_sql';
  #push @where, $class->$method();
  push @where, FS::cust_main->$method();
}

if ( $cgi->param('out') ) {

  push @where, "
    0 = (
      SELECT COUNT(*) FROM cust_main_county AS county_out
      WHERE (    county_out.county  = cust_main.county
              OR ( county_out.county IS NULL AND cust_main.county  =  '' )
              OR ( county_out.county  =  ''  AND cust_main.county IS NULL)
              OR ( county_out.county IS NULL AND cust_main.county IS NULL)
            )
        AND (    county_out.state   = cust_main.state
              OR ( county_out.state  IS NULL AND cust_main.state  =  ''  )
              OR ( county_out.state   =  ''  AND cust_main.state IS NULL )
              OR ( county_out.state  IS NULL AND cust_main.state IS NULL )
            )
        AND county_out.country = cust_main.country
        AND county_out.tax > 0
    )
  ";

} elsif ( $cgi->param('country' ) ) {

  my $county  = dbh->quote( $cgi->param('county')  );
  my $state   = dbh->quote( $cgi->param('state')   );
  my $country = dbh->quote( $cgi->param('country') );
  push @where, "( county  = $county OR $county = '' )",
               "( state   = $state  OR $state = ''  )",
               "  country = $country";
  push @where, 'taxclass = '. dbh->quote( $cgi->param('taxclass') )
    if $cgi->param('taxclass');

}

my $where = scalar(@where) ? 'WHERE '.join(' AND ', @where) : '';

my $count_query = "SELECT COUNT(*), SUM(amount)".
                  "  FROM cust_tax_exempt $join_cust $where";

my $query = {
  'table'     => 'cust_tax_exempt',
  'addl_from' => $join_cust,
  'hashref'   => {},
  'select'    => join(', ',
                   'cust_tax_exempt.*',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $where,
};

my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

</%init>
