<& elements/svc_Common.html,
  'title'       => 'Circuit Search Results',
  'name'        => 'circuit services',
  'query'       => $query,
  'count_query' => $query->{'count_query'},
  'redirect'    => [ popurl(2). "view/svc_circuit.html?", 'svcnum' ],
  'header'      => [ '#',
                     'Provider',
                     'Type',
                     'Termination',
                     'Circuit ID',
                     'IP Address',
                     FS::UI::Web::cust_header($cgi->param('cust_fields')),
                   ],
  'fields'      => [ 'svcnum',
                     'provider',
                     'typename',
                     'termination',
                     'circuit_id',
                     'ip_addr',
                     \&FS::UI::Web::cust_fields,
                   ],
  'links'       => [ $link,
                     '',
                     '',
                     '',
                     $link,
                     $link,
                     FS::UI::Web::cust_links($cgi->param('cust_fields')),
                   ],
  'align'       => 'rlllll'.  FS::UI::Web::cust_aligns(),
  'color'       => [ 
                     ('') x 6,
                     FS::UI::Web::cust_colors(),
                   ],
  'style'       => [ 
                     ('') x 6,
                     FS::UI::Web::cust_styles(),
                   ],

&>
<%init>

die "access denied" unless
  $FS::CurrentUser::CurrentUser->access_right('List services');

my $conf = new FS::Conf;

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
}

my $query = FS::svc_circuit->search(\%search_hash);

my $link = [ $p.'view/svc_circuit.html?', 'svcnum' ];

</%init>
