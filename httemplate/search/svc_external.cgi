<& elements/svc_Common.html,
                 'title'             => 'External service search results',
                 'name'              => 'external services',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $redirect,
                 'header'            => [ '#',
                                          'Service',
                                          ( FS::Msgcat::_gettext('svc_external-id') || 'External ID' ),
                                          ( FS::Msgcat::_gettext('svc_external-title') || 'Title' ),
                                          emt('Pkg. Status'),
                                          FS::UI::Web::cust_header(),
                                        ],
                 'fields'            => [ 'svcnum',
                                          'svc',
                                          'id',
                                          'title',
                                          sub {
                                            $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                            $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                                          },
                                          \&FS::UI::Web::cust_fields,
                                        ],
                 'links'             => [ $link,
                                          $link,
                                          $link,
                                          $link,
                                          '', # pkg status
                                          ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                                FS::UI::Web::cust_header()
                                          ),
                                        ],
                 'align' => 'rlrrr'.
                            FS::UI::Web::cust_aligns(),
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

my %svc_external;
my @extra_sql = ();
my $orderby = 'ORDER BY svcnum';

my $link = [ "${p}view/svc_external.cgi?", 'svcnum' ];
my $redirect = $link;

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

} elsif ( $cgi->param('title') =~ /^(.*)$/ ) {

  $svc_external{'title'} = $1;
  $orderby = 'ORDER BY id';

  # is this linked from anywhere???
  # if( $cgi->param('history') == 1 ) {
  #   @h_svc_external=qsearch('h_svc_external',{ title => $1 });
  # }

} elsif ( $cgi->param('id') =~ /^([\w\-\.]+)$/ ) {

  $svc_external{'id'} = $1;

}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                FS::UI::Web::join_cust_main('cust_pkg', 'cust_pkg');

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql(
                   'null_right' => 'View/link unlinked services'
                 );

my $extra_sql = '';
if ( @extra_sql ) {
  $extra_sql = ( keys(%svc_external) ? ' AND ' : ' WHERE ' ).
               join(' AND ', @extra_sql );
}

my $count_query = "SELECT COUNT(*) FROM svc_external $addl_from ";
if ( keys %svc_external ) {
  $count_query .= ' WHERE '.
                    join(' AND ', map "$_ = ". dbh->quote($svc_external{$_}),
                                      keys %svc_external
                        );
}
$count_query .= $extra_sql;

my $sql_query = {
  'table'     => 'svc_external',
  'hashref'   => \%svc_external,
  'select'    => join(', ',
                   'svc_external.*',
                   'part_svc.svc',
                   'cust_main.custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => $extra_sql,
  'order_by'  => $orderby,
  'addl_from' => $addl_from,
};

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};


</%init>
