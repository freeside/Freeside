<% include('elements/browse.html',
                'title'           => 'Routers',
                'menubar'         => [ @menubar ],
                'name_singular'   => 'router',
                'query'           => { 'table'     => 'router',
                                       'hashref'   => {},
                                       'extra_sql' => $extra_sql,
                                     },
                'count_query'     => "SELECT count(*) from router $count_sql",
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
                'agent_virt'      => 1,
                'agent_null_right'=> "Broadband global configuration",
                'agent_pos'       => 1,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Broadband configuration')
  || $FS::CurrentUser::CurrentUser->access_right('Broadband global configuration');

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

my $count_sql = $extra_sql.  ( $extra_sql =~ /WHERE/ ? ' AND' : 'WHERE' ).
  $FS::CurrentUser::CurrentUser->agentnums_sql(
    'null_right' => 'Broadband global configuration',
  );

</%init>
