<%

my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors

my $orderby = 'ORDER BY svcnum';
my $join = '';
my %svc_domain = ();
my $extra_sql = '';
if ( $query eq 'svcnum' ) {
  #$orderby = 'ORDER BY svcnum';
} elsif ( $query eq 'domain' ) {
  $orderby = 'ORDER BY domain';
} elsif ( $query eq 'UN_svcnum' ) {
  #$orderby = 'ORDER BY svcnum';
  $join = 'LEFT JOIN cust_svc USING ( svcnum )';
  $extra_sql = ' WHERE pkgnum IS NULL';
} elsif ( $query eq 'UN_domain' ) {
  $orderby = 'ORDER BY domain';
  $join = 'LEFT JOIN cust_svc USING ( svcnum )';
  $extra_sql = ' WHERE pkgnum IS NULL';
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  #$orderby = 'ORDER BY svcnum';
  $join = 'LEFT JOIN cust_svc USING ( svcnum )';
  $extra_sql = " WHERE svcpart = $1";
} else {
  $cgi->param('domain') =~ /^([\w\-\.]+)$/; 
  $join = '';
  $svc_domain{'domain'} = $1;
}

my $count_query = "SELECT COUNT(*) FROM svc_domain $join $extra_sql";
if ( keys %svc_domain ) {
  $count_query .= ' WHERE '.
                    join(' AND ', map "$_ = ". dbh->quote($svc_domain{$_}),
                                      keys %svc_domain
                        );
}

my $sql_query = {
  'table'     => 'svc_domain',
  'hashref'   => \%svc_domain,
  'select'    => join(', ',
                   'svc_domain.*',
                    'cust_main.custnum',
                    FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => "$extra_sql $orderby",
  'addl_from' => 'LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 'LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 'LEFT JOIN cust_main USING ( custnum ) ',
};

my $link = [ "${p}view/svc_domain.cgi?", 'svcnum' ];

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

%><%= include ('elements/search.html',
                 'title'             => "Domain Search Results",
                 'name'              => 'domains',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $link,
                 'header'            => [ '#',
                                          'Domain',
                                          FS::UI::Web::cust_header(),
                                        ],
                 'fields'            => [ 'svcnum',
                                          'domain',
                                          \&FS::UI::Web::cust_fields,
                                        ],
                 'links'             => [ $link,
                                          $link,
                                          ( map { $link_cust }
                                                FS::UI::Web::cust_header()
                                          ),
                                        ],
              )
%>
