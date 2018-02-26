<& elements/svc_Common.html,
              'title'       => 'Broadband Search Results',
              'name'        => 'broadband services',
              'html_init'   => $html_init,
              'query'       => $sql_query,
              'count_query' => $sql_query->{'count_query'},
              'redirect'    => [ popurl(2). "view/svc_broadband.cgi?", 'svcnum' ],
              'header'      => [ '#',
                                 'Service',
                                 'Router',
                                 @tower_header,
                                 'IP Address',
                                 @header_pkg,
                                 emt('Pkg. Status'),
                                 FS::UI::Web::cust_header($cgi->param('cust_fields')),
                               ],
              'fields'      => [ 'svcnum',
                                 'svc',
                                 sub {
                                   my $router = shift->router; 
                                   $router ? $router->routername : '';
                                 },
                                 @tower_fields,
                                 'ip_addr',
                                 @fields_pkg,
                                 sub {
                                   $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                   return '' unless $cust_pkg_cache{$_[0]->svcnum};
                                   $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                                 },
                                 \&FS::UI::Web::cust_fields,
                               ],
              'links'       => [ $link,
                                 $link,
                                 '', #$link_router,
                                 (map '', @tower_fields),
                                 $link, # ip_addr
                                 @blank_pkg,
                                 '', # pkg status
                                 ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                       FS::UI::Web::cust_header($cgi->param('cust_fields'))
                                 ),
                               ],
              'align'       => 'rll'.('r' x @tower_fields).
                                'r'. # ip_addr
                                $align_pkg.
                                'r'. # pkg status
                                FS::UI::Web::cust_aligns(),
              'color'       => [ 
                                 '',
                                 '',
                                 '',
                                 (map '', @tower_fields),
                                 '', # ip_addr
                                 @blank_pkg,
                                 sub {
                                   $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                   return '' unless $cust_pkg_cache{$_[0]->svcnum};
                                   my $c = FS::cust_pkg::statuscolors;
                                   $c->{$cust_pkg_cache{$_[0]->svcnum}->status };
                                 }, # pkg status
                                 FS::UI::Web::cust_colors(),
                               ],
              'style'       => [ 
                                 '',
                                 '',
                                 '',
                                 (map '', @tower_fields),
                                 '',  # ip_addr
                                 @blank_pkg,
                                 'b', # pkg status
                                 FS::UI::Web::cust_styles(),
                               ],
          
&>
<%init>

die "access denied" unless
  $FS::CurrentUser::CurrentUser->access_right('List services');

my %cust_pkg_cache;

my $conf = new FS::Conf;

$m->comp('/elements/handle_uri_query');

my %search_hash;
if ( $cgi->param('magic') eq 'unlinked' ) {
  %search_hash = ( 'unlinked' => 1 );
} else {
  foreach (qw( custnum agentnum svcpart cust_fields )) {
    $search_hash{$_} = $cgi->param($_) if $cgi->param($_);
  }
  foreach (qw(pkgpart routernum towernum sectornum)) {
    $search_hash{$_} = [ $cgi->param($_) ] if $cgi->param($_);
  }
  if ( defined($cgi->param('cancelled')) ) {
    $search_hash{'cancelled'} = $cgi->param('cancelled') ? 1 : 0;
  }
}

if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
  $search_hash{'order_by'} = "ORDER BY $1";
}

my $sql_query = FS::svc_broadband->search(\%search_hash);

my @tower_header;
my @tower_fields;
if ( FS::tower_sector->count > 0 ) {
  push @tower_header, 'Tower/Sector';
  push @tower_fields, sub { $_[0]->tower_sector ? 
                            $_[0]->tower_sector->description : '' };
}

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

my $query = $m->scomp('/elements/create_uri_query');

$html_init .= ' | ' .
  '<a href="' .
  $fsurl . 'search/svc_broadband-map.html?' . $query .
  '">' . emt('View a map of these services') . '</a>';

my (@header_pkg,@fields_pkg,@blank_pkg);
my $align_pkg = '';
#false laziness with search/svc_acct.cgi
$cgi->param('cust_pkg_fields') =~ /^([\w\,]*)$/ or die "bad cust_pkg_fields";
my @pkg_fields = split(',', $1);
foreach my $pkg_field ( @pkg_fields ) {
  ( my $header = ucfirst($pkg_field) ) =~ s/_/ /; #:/
  push @header_pkg, $header;

  #not the most efficient to do it every field, but this is of niche use. so far
  push @fields_pkg, sub { my $svc_x = shift;
                          my $cust_pkg = $svc_x->cust_svc->cust_pkg or return '';
                          my $value;
                          if ($pkg_field eq 'package') {
                            $value = $cust_pkg->part_pkg->pkg;
                            #$value = $cust_pkg->pkg_label;
                          }
                          else {
                            $value = $cust_pkg->get($pkg_field);#closures help alot 
                            $value ? time2str('%b %d %Y', $value ) : '';
                          }
                        };

  push @blank_pkg, '';
  $align_pkg .= 'c';
}


</%init>
