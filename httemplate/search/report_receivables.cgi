<% include( 'elements/search.html',
                 'title'       => 'Accounts Receivable Aging Summary',
                 'name'        => 'customers',
                 'query'       => $sql_query,
                 'count_query' => $count_sql,
                 'header'      => [
                                    FS::UI::Web::cust_header(),
                                    '0-30',
                                    '30-60',
                                    '60-90',
                                    '90+',
                                    'Total',
                                  ],
                 'footer'      => [
                                    'Total',
                                    ( map '',
                                          ( 1 .. 
                                            scalar(FS::UI::Web::cust_header()-1)
                                          )
                                    ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'balance_0_30'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'balance_30_60'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'balance_60_90'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'balance_90_0'} ),
                                    sprintf( '<b>'. $money_char.'%.2f'. '</b>',
                                             $row->{'balance_0_0'} ),
                                  ],
                 'fields'      => [
                                    \&FS::UI::Web::cust_fields,
                                    format_balance('0_30'),
                                    format_balance('30_60'),
                                    format_balance('60_90'),
                                    format_balance('90_0'),
                                    format_balance('0_0'),
                                  ],
                 'links'       => [
                                    ( map { $_ ne 'Cust. Status' ? $clink : '' }
                                          FS::UI::Web::cust_header()
                                    ),
                                    '',
                                    '',
                                    '',
                                    '',
                                    '',
                                  ],
                 #'align'       => 'rlccrrrrr',
                 'align'       => FS::UI::Web::cust_aligns(). 'rrrrr',
                 #'size'        => [ '', '', '-1', '-1', '', '', '', '',  '', ],
                 #'style'       => [ '', '',  'b',  'b', '', '', '', '', 'b', ],
                 'size'        => [ ( map '', FS::UI::Web::cust_header() ),
                                    #'-1', '', '', '', '',  '', ],
                                    '', '', '', '',  '', ],
                 'style'       => [ FS::UI::Web::cust_styles(),
                                    #'b', '', '', '', '', 'b', ],
                                    '', '', '', '', 'b', ],
                 'color'       => [
                                    FS::UI::Web::cust_colors(),
                                    '',
                                    '',
                                    '',
                                    '',
                                    '',
                                  ],

             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Receivables report')
      or $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my @ranges = (
  [  0, 30 ],
  [ 30, 60 ],
  [ 60, 90 ],
  [ 90,  0 ],
  [  0,  0 ],
);

my $owed_cols = join(',', map balance( @$_ ), @ranges );

my $select_count_pkgs = FS::cust_main->select_count_pkgs_sql;

my $active_sql    = FS::cust_pkg->active_sql;
my $inactive_sql  = FS::cust_pkg->inactive_sql;
my $suspended_sql = FS::cust_pkg->suspended_sql;
my $cancelled_sql = FS::cust_pkg->cancelled_sql;

my $packages_cols = <<END;
     ( $select_count_pkgs                    ) AS num_pkgs_sql,
     ( $select_count_pkgs AND $active_sql    ) AS active_pkgs,
     ( $select_count_pkgs AND $inactive_sql  ) AS inactive_pkgs,
     ( $select_count_pkgs AND $suspended_sql ) AS suspended_pkgs,
     ( $select_count_pkgs AND $cancelled_sql ) AS cancelled_pkgs
END

my @where = ();

unless ( $cgi->param('all_customers') ) {

  my $days = 0;
  if ( $cgi->param('days') =~ /^\s*(\d+)\s*$/ ) {
    $days = $1;
  }

  push @where, balance($days, 0, 'no_as'=>1). ' > 0'; # != 0';

}

if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agentnum = $1;
  push @where, "agentnum = $agentnum";
}

#status (false laziness w/cust_main::search_sql

#prospect active inactive suspended cancelled
if ( grep { $cgi->param('status') eq $_ } FS::cust_main->statuses() ) {
  my $method = $cgi->param('status'). '_sql';
  #push @where, $class->$method();
  push @where, FS::cust_main->$method();
}

#here is the agent virtualization
push @where, $FS::CurrentUser::CurrentUser->agentnums_sql;

my $where = join(' AND ', @where);
$where = "WHERE $where" if $where;

my $count_sql = "select count(*) from cust_main $where";

my $sql_query = {
  'table'     => 'cust_main',
  'hashref'   => {},
  'select'    => join(',',
                   #'cust_main.*',
                   'custnum',
                   $owed_cols,
                   $packages_cols,
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $where,
  'order_by'  => "order by coalesce(lower(company), ''), lower(last)",
};

my $total_sql = "SELECT ". join(',', map balance( @$_, 'sum'=>1 ), @ranges).
                " FROM cust_main $where";

my $total_sth = dbh->prepare($total_sql) or die dbh->errstr;
$total_sth->execute or die "error executing $total_sql: ". $total_sth->errstr;
my $row = $total_sth->fetchrow_hashref();

my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

</%init>
<%once>

my $conf = new FS::Conf;

my $money_char = $conf->config('money_char') || '$';

#Example:
#
# my $balance = balance(
#   $start, $end, 
#   'no_as'  => 1, #set to true when using in a WHERE clause (supress AS clause)
#                 #or 0 / omit when using in a SELECT clause as a column
#                 #  ("AS balance_$start_$end")
#   'sum'    => 1, #set to true to get a SUM() of the values, for totals
#
#   #obsolete? options for totals (passed to cust_main::balance_date_sql)
#   'total'  => 1, #set to true to remove all customer comparison clauses
#   'join'   => $join,   #JOIN clause
#   'where'  => \@where, #WHERE clause hashref (elements "AND"ed together)
# )

sub balance {
  my($start, $end, %opt) = @_;

  my $as = $opt{'no_as'} ? '' : " AS balance_${start}_$end";

  #handle start and end ranges (86400 = 24h * 60m * 60s)
  my $str2time = str2time_sql;
  my $closing = str2time_sql_closing;
  $start = $start ? "( $str2time now() $closing - ".($start * 86400). ' )' : '';
  $end   = $end   ? "( $str2time now() $closing - ".($end   * 86400). ' )' : '';

  $opt{'unapplied_date'} = 1;

  ( $opt{sum} ? 'SUM( ' : '' ). 
  FS::cust_main->balance_date_sql( $start, $end, %opt ).
  ( $opt{sum} ? ' )' : '' ). 
  $as;

}

sub format_balance { #closures help alot
  my $range = shift;
  sub { sprintf( $money_char.'%.2f', shift->get("balance_$range") ) };
}

</%once>
