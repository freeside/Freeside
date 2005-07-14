<%

#my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my $orderby;
if ( $query eq 'svcnum' ) {
  $orderby = 'ORDER BY svcnum';
} else {
  eidiot('unimplemented');
}

my $count_query = 'SELECT COUNT(*) FROM svc_www';
my $sql_query = {
  'table'     => 'svc_www',
  'hashref'   => {},
  'select'    => join(', ',
                   'svc_www.*',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $orderby,
  'addl_from' => 'LEFT JOIN cust_svc  USING ( svcnum  )'.
                 'LEFT JOIN cust_pkg  USING ( pkgnum  )'.
                 'LEFT JOIN cust_main USING ( custnum )',
};

my $link  = [ "${p}view/svc_www.cgi?", 'svcnum', ];
#my $dlink = [ "${p}view/svc_www.cgi?", 'svcnum', ];
my $ulink = [ "${p}view/svc_acct.cgi?", 'usersvc', ];

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

%><%= include( 'elements/search.html',
                 'title'       => 'Virtual Host Search Results',
                 'name'        => 'virtual hosts',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => [ '#',
                                    'Zone',
                                    'User',
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields'      => [ 'svcnum',
                                    sub { $_[0]->domain_record->zone },
                                    sub {
                                          my $svc_www = shift;
                                          my $svc_acct = $svc_www->svc_acct;
                                          $svc_acct
                                            ? $svc_acct->email
                                            : '';
                                        },
                                    \&FS::UI::Web::cust_fields,
                                  ],
                 'links'       => [ $link,
                                    '',
                                    $ulink,
                                    ( map { $link_cust }
                                          FS::UI::Web::cust_header()
                                    ),
                                  ],
             )
%>
