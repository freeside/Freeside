<& elements/svc_Common.html,
  'title'       => 'Circuit Search Results',
  'name'        => 'circuit services',
  'query'       => $query,
  'count_query' => $query->{'count_query'},
  'redirect'    => [ popurl(2). "view/svc_circuit.cgi?", 'svcnum' ],
  'header'      => [ '#',
                     'Provider',
                     'Type',
                     'Termination',
                     'Circuit ID',
                     'IP Address',
                     emt('Pkg. Status'),
                     FS::UI::Web::cust_header($cgi->param('cust_fields')),
                   ],
  'fields'      => [ 'svcnum',
                     'provider',
                     'typename',
                     'termination',
                     'circuit_id',
                     'ip_addr',
                     sub {
                       $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                       return '' unless $cust_pkg_cache{$_[0]->svcnum};
                       $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                     },
                     \&FS::UI::Web::cust_fields,
                   ],
  'links'       => [ $link,
                     '',
                     '',
                     '',
                     $link,
                     $link,
                     '', # pkg status
                     FS::UI::Web::cust_links($cgi->param('cust_fields')),
                   ],
  'align'       => 'rlllllr'.  FS::UI::Web::cust_aligns(),
  'color'       => [ 
                     ('') x 6,
                     sub {
                       $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                       return '' unless $cust_pkg_cache{$_[0]->svcnum};
                       my $c = FS::cust_pkg::statuscolors;
                       $c->{$cust_pkg_cache{$_[0]->svcnum}->status };
                     }, # pkg status
                     FS::UI::Web::cust_colors(),
                   ],
  'style'       => [ 
                     ('') x 6,
                     'b',
                     FS::UI::Web::cust_styles(),
                   ],

&>
<%init>

die "access denied" unless
  $FS::CurrentUser::CurrentUser->access_right('List services');

my %cust_pkg_cache;

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
  if ( defined($cgi->param('cancelled')) ) {
    $search_hash{'cancelled'} = $cgi->param('cancelled') ? 1 : 0;
  }
}

my $query = FS::svc_circuit->search(\%search_hash);

my $link = [ $p.'view/svc_circuit.cgi?', 'svcnum' ];

</%init>
