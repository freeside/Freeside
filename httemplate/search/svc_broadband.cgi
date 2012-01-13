<% include( 'elements/search.html',
              'title'       => 'Broadband Search Results',
              'name'        => 'broadband services',
              'html_init'   => $html_init,
              'query'       => $sql_query,
              'count_query' => $sql_query->{'count_query'},
              'redirect'    => [ popurl(2). "view/svc_broadband.cgi?", 'svcnum' ],
              'header'      => [ '#',
                                 'Service',
                                 'Router',
                                 'IP Address',
                                 FS::UI::Web::cust_header($cgi->param('cust_fields')),
                               ],
              'fields'      => [ 'svcnum',
                                 'svc',
                                 sub {
                                   my $blocknum = shift->blocknum or return '';
                                   $routerbyblock{$blocknum}->routername;
                                 },
                                 'ip_addr',
                                 \&FS::UI::Web::cust_fields,
                               ],
              'links'       => [ $link,
                                 $link,
                                 '', #$link_router,
                                 $link,
                                 ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                       FS::UI::Web::cust_header($cgi->param('cust_fields'))
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

die "access denied" unless
  $FS::CurrentUser::CurrentUser->access_right('List services');

my $conf = new FS::Conf;

my %search_hash;
if ( $cgi->param('magic') eq 'unlinked' ) {
  %search_hash = ( 'unlinked' => 1 );
}
else {
  foreach (qw(custnum agentnum svcpart)) {
    $search_hash{$_} = $cgi->param($_) if $cgi->param($_);
  }
  foreach (qw(pkgpart routernum)) {
    $search_hash{$_} = [ $cgi->param($_) ] if $cgi->param($_);
  }
}

if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
  $search_hash{'order_by'} = $1;
}

my $sql_query = FS::svc_broadband->search(\%search_hash);

my %routerbyblock = ();
foreach my $router (qsearch('router', {})) {
  foreach ($router->addr_block) {
    $routerbyblock{$_->blocknum} = $router;
  }
}

my $link = [ $p.'view/svc_broadband.cgi?', 'svcnum' ];

#XXX get the router link working
#my $link_router = sub {
#  my $routernum = $routerbyblock{shift->blocknum}->routernum;
#  [ $p.'view/router.cgi?'.$routernum, 'routernum' ];
#};

my $link_cust = [ $p.'view/cust_main.cgi?', 'custnum' ];

my $html_init = include('/elements/email-link.html',
                  'search_hash' => \%search_hash,
                  'table' => 'svc_broadband' 
                );

</%init>
