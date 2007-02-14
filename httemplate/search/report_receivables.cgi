<% include( 'elements/search.html',
                 'title'       => 'Accounts Receivable Aging Summary',
                 'name'        => 'customers',
                 'query'       => $sql_query,
                 'count_query' => $count_sql,
                 'header'      => [
                                    FS::UI::Web::cust_header(),
                                    #'Status', # (me)',
                                    #'Status', # (cust_main)',
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
                                    #'',
                                    #'',
                                    sprintf( $money_char.'%.2f',
                                             $row->{'owed_0_30'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'owed_30_60'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'owed_60_90'} ),
                                    sprintf( $money_char.'%.2f',
                                             $row->{'owed_90_0'} ),
                                    sprintf( '<b>'. $money_char.'%.2f'. '</b>',
                                             $row->{'owed_0_0'} ),
                                  ],
                 'fields'      => [
                                    \&FS::UI::Web::cust_fields,
                                    #sub { ( &{$status_statuscol}(shift) )[0] },
                                    #sub { ucfirst(shift->status) },
                                    sub { sprintf( $money_char.'%.2f',
                                                   shift->get('owed_0_30') ) },
                                    sub { sprintf( $money_char.'%.2f',
                                                   shift->get('owed_30_60') ) },
                                    sub { sprintf( $money_char.'%.2f',
                                                   shift->get('owed_60_90') ) },
                                    sub { sprintf( $money_char.'%.2f',
                                                   shift->get('owed_90_0') ) },
                                    sub { sprintf( $money_char.'%.2f',
                                                   shift->get('owed_0_0') ) },
                                  ],
                 'links'       => [
                                    ( map { $_ ne 'Cust. Status' ? $clink : '' }
                                          FS::UI::Web::cust_header()
                                    ),
                                    #'',
                                    #'',
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
                                    #sub { ( &{$status_statuscol}(shift) )[1] },
                                    #sub { shift->statuscolor; },
                                    '',
                                    '',
                                    '',
                                    '',
                                    '',
                                  ],

             )
%>
<%once>

sub owed {
  my($start, $end, %opt) = @_;

  my @where = ();

  #handle start and end ranges

  #24h * 60m * 60s
  push @where, "cust_bill._date <= extract(epoch from now())-".
               ($start * 86400)
    if $start;

  push @where, "cust_bill._date > extract(epoch from now()) - ".
               ($end * 86400)
    if $end;

  #handle 'cust' option

  push @where, "cust_main.custnum = cust_bill.custnum"
    if $opt{'cust'};

  #handle 'agentnum' option
  my $join = '';
  if ( $opt{'agentnum'} ) {
    $join = 'LEFT JOIN cust_main USING ( custnum )';
    push @where, "agentnum = '$opt{'agentnum'}'";
  }

  my $where = scalar(@where) ? 'WHERE '.join(' AND ', @where) : '';

  my $as = $opt{'noas'} ? '' : "as owed_${start}_$end";

  my $charged = <<END;
sum( charged
     - coalesce(
         ( select sum(amount) from cust_bill_pay
           where cust_bill.invnum = cust_bill_pay.invnum )
         ,0
       )
     - coalesce(
         ( select sum(amount) from cust_credit_bill
           where cust_bill.invnum = cust_credit_bill.invnum )
         ,0
       )

   )
END

  "coalesce( ( select $charged from cust_bill $join $where ) ,0 ) $as";

}

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my @ranges = (
  [  0, 30 ],
  [ 30, 60 ],
  [ 60, 90 ],
  [ 90,  0 ],
  [  0,  0 ],
);

my $owed_cols = join(',', map owed( @$_, 'cust'=>1 ), @ranges );

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

my $days = 0;
if ( $cgi->param('days') =~ /^\s*(\d+)\s*$/ ) {
  $days = $1;
}

#my $where = "where ". owed(0, 0, 'cust'=>1, 'noas'=>1). " > 0";
my $where = "where ". owed($days, 0, 'cust'=>1, 'noas'=>1). " > 0";

my $agentnum = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $where .= " AND agentnum = '$agentnum' ";
}

#here is the agent virtualization
$where .= ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql;

my $count_sql = "select count(*) from cust_main $where";

my $sql_query = {
  'table'     => 'cust_main',
  'hashref'   => {},
  'select'    => "*, $owed_cols, $packages_cols",
  'extra_sql' => "$where order by coalesce(lower(company), ''), lower(last)",
};

my $total_sql = "select ".
                  join(',', map owed( @$_, 'agentnum'=>$agentnum ), @ranges );

my $total_sth = dbh->prepare($total_sql) or die dbh->errstr;
$total_sth->execute or die "error executing $total_sql: ". $total_sth->errstr;
my $row = $total_sth->fetchrow_hashref();

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

my $status_statuscol = sub {
  #conceptual false laziness with cust_main::status...
  my $row = shift;

  my $status = 'unknown';
  if ( $row->num_pkgs_sql == 0 ) {
    $status = 'prospect';
  } elsif ( $row->active_pkgs    > 0 ) {
    $status = 'active';
  } elsif ( $row->inactive_pkgs  > 0 ) {
    $status = 'inactive';
  } elsif ( $row->suspended_pkgs > 0 ) {
    $status = 'suspended';
  } elsif ( $row->cancelled_pkgs > 0 ) {
    $status = 'cancelled'
  }

  ( ucfirst($status), $FS::cust_main::statuscolor{$status} );
};

</%init>
