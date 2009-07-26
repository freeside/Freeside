<% include( 'elements/search.html',
              'title'       => 'Broadband Search Results',
              'name'        => 'broadband services',
              'query'       => $sql_query,
              'count_query' => $count_query,
              'redirect'    => [ popurl(2). "view/svc_broadband.cgi?", 'svcnum' ],
              'header'      => [ '#',
                                 'Service',
                                 'Router',
                                 'IP Address',
                                 FS::UI::Web::cust_header(),
                               ],
              'fields'      => [ 'svcnum',
                                 'svc',
                                 sub { $routerbyblock{shift->blocknum}->routername; },
                                 'ip_addr',
                                 \&FS::UI::Web::cust_fields,
                               ],
              'links'       => [ $link,
                                 $link,
                                 $link_router,
                                 $link,
                                 ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                       FS::UI::Web::cust_header()
                                 ),
                               ],
              'align'       => 'rllr'. FS::UI::Web::cust_aligns(),
              'color'       => [ 
                                 '',
                                 '',
                                 '',
                                 '',
                                 FS::UI::Web::cust_colors(),
                               ],
              'style'       => [ 
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
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

my $conf = new FS::Conf;

my $orderby = 'ORDER BY svcnum';
my %svc_broadband = ();
my @extra_sql = ();
if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  push @extra_sql, 'pkgnum IS NULL'
    if $cgi->param('magic') eq 'unlinked';

  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    my $sortby = $1;
    $orderby = "ORDER BY $sortby";
  }

} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  push @extra_sql, "svcpart = $1";
} elsif ( $cgi->param('ip_addr') =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
  push @extra_sql, "ip_addr = '$1'";
}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql( 
                   'null_right' => 'View/link unlinked services'
                 );

my $extra_sql = '';
if ( @extra_sql ) {
  $extra_sql = ( keys(%svc_broadband) ? ' AND ' : ' WHERE ' ).
               join(' AND ', @extra_sql );
}

my $count_query = "SELECT COUNT(*) FROM svc_broadband $addl_from ";
#if ( keys %svc_broadband ) {
#  $count_query .= ' WHERE '.
#                    join(' AND ', map "$_ = ". dbh->quote($svc_broadband{$_}),
#                                      keys %svc_broadband
#                        );
#}
$count_query .= $extra_sql;

my $sql_query = {
  'table'     => 'svc_broadband',
  'hashref'   => {}, #\%svc_broadband,
  'select'    => join(', ',
                   'svc_broadband.*',
                   'part_svc.svc',
                    'cust_main.custnum',
                    FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'addl_from' => $addl_from,
};

my %routerbyblock = ();
foreach my $router (qsearch('router', {})) {
  foreach ($router->addr_block) {
    $routerbyblock{$_->blocknum} = $router;
  }
}

my $link = [ $p.'view/svc_broadband.cgi?', 'svcnum' ];

#XXX get the router link working
my $link_router = sub { my $routernum = $routerbyblock{shift->blocknum}->routernum;
                        [ $p.'view/router.cgi?'.$routernum, 'routernum' ];
                      };

my $link_cust = [ $p.'view/cust_main.cgi?', 'custnum' ];

</%init>
