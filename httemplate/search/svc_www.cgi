<& elements/svc_Common.html,
                 'title'       => 'Virtual Host Search Results',
                 'name'        => 'virtual hosts',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => [ '#',
                                    'Service',
                                    'Zone',
                                    'User',
                                    emt('Pkg. Status'),
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields'      => [ 'svcnum',
                                    'svc',
                                    sub { $_[0]->domain_record->zone },
                                    sub {
                                          my $svc_www = shift;
                                          my $svc_acct = $svc_www->svc_acct;
                                          $svc_acct
                                            ? $svc_acct->email
                                            : '';
                                        },
                                    sub {
                                      $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                      $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                                    },
                                    \&FS::UI::Web::cust_fields,
                                  ],
                 'links'       => [ $link,
                                    $link,
                                    '',
                                    $ulink,
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

#my $conf = new FS::Conf;

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


my $count_query = "SELECT COUNT(*) FROM svc_www $addl_from $extra_sql";
my $sql_query = {
  'table'     => 'svc_www',
  'hashref'   => {},
  'select'    => join(', ',
                   'svc_www.*',
                   'part_svc.svc',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'order_by'  => $orderby,
  'addl_from' => $addl_from,
};

my $link  = [ "${p}view/svc_www.cgi?", 'svcnum', ];
#my $dlink = [ "${p}view/svc_www.cgi?", 'svcnum', ];
my $ulink = [ "${p}view/svc_acct.cgi?", 'usersvc', ];

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

</%init>
