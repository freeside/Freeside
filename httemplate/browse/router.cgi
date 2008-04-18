<% include('elements/browse.html',
                'title'           => 'Routers',
                'menubar'         => [ @menubar ],
                'name_singular'   => 'router',
                'query'           => { 'table'     => 'router',
                                       'hashref'   => {},
                                       'extra_sql' => $extra_sql,
                                     },
                'count_query'     => "SELECT count(*) from router $extra_sql",
                'header'          => [ 'Router name',
                                       'Address block(s)',
                                     ],
                'fields'          => [ 'routername',
                                       sub { join( '<BR>', map { $_->NetAddr }
                                                               shift->addr_block
                                                 );
                                           },
                                     ],
                'links'           => [ [ "${p2}edit/router.cgi?", 'routernum' ],
                                       '',
                                     ],
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $p2 = popurl(2);
my $extra_sql = '';

my @menubar = ( 'Add a new router', "${p2}edit/router.cgi" );

if ($cgi->param('hidecustomerrouters') eq '1') {
  $extra_sql = 'WHERE svcnum > 0';
  $cgi->param('hidecustomerrouters', 0);
  push @menubar, 'Show customer routers', $cgi->self_url();
} else {
  $cgi->param('hidecustomerrouters', 1);
  push @menubar, 'Hide customer routers', $cgi->self_url();
}

</%init>
