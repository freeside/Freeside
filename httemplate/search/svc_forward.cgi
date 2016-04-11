<& elements/search.html,
                 'title'             => "Mail forward Search Results",
                 'name'              => 'mail forwards',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $link,
                 'header'            => [ '#',
                                          'Service',
                                          'Mail to',
                                          'Forwards to',
                                          emt('Pkg. Status'),
                                          FS::UI::Web::cust_header(),
                                        ],
                 'fields'            => [ 'svcnum',
                                          'svc',
                                          $format_src,
                                          $format_dst,
                                          sub {
                                            $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                            $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                                          },
                                          \&FS::UI::Web::cust_fields,
                                        ],
                 'links'             => [ $link,
                                          $link,
                                          $link_src,
                                          $link_dst,
                                          '', # pkg status
                                          ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                                FS::UI::Web::cust_header()
                                          ),
                                        ],
                 'align' => 'rlllr'. FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              sub {
                                my $c = FS::cust_pkg::statuscolors;
                                $c->{$cust_pkg_cache{$_[0]->svcnum}->status };
                              }, # pkg status
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              'b',
                              FS::UI::Web::cust_styles(),
                            ],
             
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

my %cust_pkg_cache;

my $conf = new FS::Conf;

my $orderby = 'ORDER BY svcnum';
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
  if (defined($cgi->param('cancelled'))) {
    if ($cgi->param('cancelled')) {
      push @extra_sql, "cust_pkg.cancel IS NOT NULL";
    } else {
      push @extra_sql, "cust_pkg.cancel IS NULL";
    }
  }
}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                FS::UI::Web::join_cust_main('cust_pkg', 'cust_pkg');

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql( 
                   'null_right' => 'View/link unlinked services'
                 );

my $extra_sql = 
  scalar(@extra_sql)
    ? ' WHERE '. join(' AND ', @extra_sql )
    : '';

my $count_query = "SELECT COUNT(*) FROM svc_forward $addl_from $extra_sql";
my $sql_query = {
  'table'     => 'svc_forward',
  'hashref'   => {},
  'select'    => join(', ',
                   'svc_forward.*',
                   'part_svc.svc',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'order_by'  => $orderby,
  'addl_from' => $addl_from,
};

#        <TH>Service #<BR><FONT SIZE=-1>(click to view forward)</FONT></TH>
#        <TH>Mail to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
#        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>

my $link = [ "${p}view/svc_forward.cgi?", 'svcnum' ];

my $format_src = sub {
  my $svc_forward = shift;
  if ( $svc_forward->srcsvc_acct ) {
    $svc_forward->srcsvc_acct->email;
  } else {
    my $src = $svc_forward->src;
    $src = "<I>(anything)</I>$src" if $src =~ /^@/;
    $src;
  }
};

my $link_src = sub {
  my $svc_forward = shift;
  if ( $svc_forward->srcsvc_acct ) {
    [ "${p}view/svc_acct.cgi?", 'srcsvc' ];
  } else {
    '';
  }
};

my $format_dst = sub {
  my $svc_forward = shift;
  if ( $svc_forward->dstsvc_acct ) {
    $svc_forward->dstsvc_acct->email;
  } else {
    $svc_forward->dst;
  }
};

my $link_dst = sub {
  my $svc_forward = shift;
  if ( $svc_forward->dstsvc_acct ) {
    [ "${p}view/svc_acct.cgi?", 'dstsvc' ];
  } else {
    '';
  }
};

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

</%init>
