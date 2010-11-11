<% include( 'elements/search.html',
                 'title'             => "Domain Search Results",
                 'name'              => 'domains',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $link,
                 'header'            => [ '#',
                                          'Service',
                                          'Domain',
                                          FS::UI::Web::cust_header(),
                                        ],
                 'fields'            => [ 'svcnum',
                                          'svc',
                                          'domain',
                                          \&FS::UI::Web::cust_fields,
                                        ],
                 'links'             => [ $link,
                                          $link,
                                          $link,
                                          ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                                FS::UI::Web::cust_header()
                                          ),
                                        ],
                 'align' => 'rll'. FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
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
my %svc_domain = ();
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
} else {
  $cgi->param('domain') =~ /^([\w\-\.]+)$/; 
  $svc_domain{'domain'} = $1;
}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql( 
                   'null_right' => 'View/link unlinked services'
                 );

my $extra_sql = '';
if ( @extra_sql ) {
  $extra_sql = ( keys(%svc_domain) ? ' AND ' : ' WHERE ' ).
               join(' AND ', @extra_sql );
}

my $count_query = "SELECT COUNT(*) FROM svc_domain $addl_from ";
if ( keys %svc_domain ) {
  $count_query .= ' WHERE '.
                    join(' AND ', map "$_ = ". dbh->quote($svc_domain{$_}),
                                      keys %svc_domain
                        );
}
$count_query .= $extra_sql;

my $sql_query = {
  'table'     => 'svc_domain',
  'hashref'   => \%svc_domain,
  'select'    => join(', ',
                   'svc_domain.*',
                   'part_svc.svc',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'order_by'  => $orderby,
  'addl_from' => $addl_from,
};

my $link = [ "${p}view/svc_domain.cgi?", 'svcnum' ];

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

</%init>
