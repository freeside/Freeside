<%

#my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my(@svc_www, $orderby);
if ( $query eq 'svcnum' ) {
  $orderby = 'ORDER BY svcnum';
} else {
  eidiot('unimplemented');
}

my $count_query = 'SELECT COUNT(*) FROM svc_www';
my $sql_query = {
  'table'     => 'svc_www',
  'hashref'   => {},
  'extra_sql' => $orderby,
};

my $link  = [ "${p}view/svc_www.cgi?", 'svcnum', ];
#my $dlink = [ "${p}view/svc_www.cgi?", 'svcnum', ];
my $ulink = [ "${p}view/svc_acct.cgi?", 'usersvc', ];


%>
<%= include( 'elements/search.html',
               'title'       => 'Virtual Host Search Results',
               'name'        => 'virtual hosts',
               'query'       => $sql_query,
               'count_query' => $count_query,
               'header'      => [ '#', 'Zone', 'User', ],
               'fields'      => [ 'svcnum',
                                  sub { $_[0]->domain_record->zone },
                                  sub { $_[0]->svc_acct->email },
                                ],
               'links'       => [ $link,
                                  '',
                                  $ulink,
                                ],
           )
%>
