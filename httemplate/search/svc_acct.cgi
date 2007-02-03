<% include( 'elements/search.html',
                 'title'       => 'Account Search Results',
                 'name'        => 'accounts',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => [ '#',
                                    'Service',
                                    'Account',
                                    'UID',
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields'      => [ 'svcnum',
                                    'svc',
                                    'email',
                                    'uid',
                                    \&FS::UI::Web::cust_fields,
                                  ],
                 'links'       => [ $link,
                                    $link,
                                    $link,
                                    $link,
                                    ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                          FS::UI::Web::cust_header()
                                    ),
                                  ],
                 'align' => 'rlll'. FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

my @extra_sql = ();

 if ( $cgi->param('domain') ) { 
   my $svc_domain =
     qsearchs('svc_domain', { 'domain' => $cgi->param('domain') } );
   unless ( $svc_domain ) {
     #it would be nice if this looked more like the other "not found"
     #errors, but this will do for now.
     eidiot "Domain ". $cgi->param('domain'). " not found at all";
   } else {
     push @extra_sql, 'domsvc = '. $svc_domain->svcnum;
   }
 }

my $orderby = 'ORDER BY svcnum';
if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  push @extra_sql, 'pkgnum IS NULL'
    if $cgi->param('magic') eq 'unlinked';

  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    my $sortby = $1;
    $sortby = "LOWER($sortby)"
      if $sortby eq 'username';
    push @extra_sql, "$sortby IS NOT NULL"
      if $sortby eq 'uid';
    $orderby = "ORDER BY $sortby";
  }

} elsif ( $cgi->param('popnum') =~ /^(\d+)$/ ) {
  push @extra_sql, "popnum = $1";
  $orderby = "ORDER BY LOWER(username)";
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  push @extra_sql, "svcpart = $1";
  $orderby = "ORDER BY uid";
  #$orderby = "ORDER BY svcnum";
} else {
  $orderby = "ORDER BY uid";

  my @username_sql;

  my %username_type;
  foreach ( $cgi->param('username_type') ) {
    $username_type{$_}++;
  }

  $cgi->param('username') =~ /^([\w\-\.\&]+)$/; #untaint username_text
  my $username = $1;

  push @username_sql, "username ILIKE '$username'"
    if $username_type{'Exact'}
    || $username_type{'Fuzzy'};

  push @username_sql, "username ILIKE '\%$username\%'"
    if $username_type{'Substring'}
    || $username_type{'All'};

  if ( $username_type{'Fuzzy'} || $username_type{'All'} ) {
    &FS::svc_acct::check_and_rebuild_fuzzyfiles;
    my $all_username = &FS::svc_acct::all_username;

    my %username;
    if ( $username_type{'Fuzzy'} || $username_type{'All'} ) { 
      foreach ( amatch($username, [ qw(i) ], @$all_username) ) {
        $username{$_}++; 
      }
    }

    #if ($username_type{'Sound-alike'}) {
    #}

    push @username_sql, "username = '$_'"
      foreach (keys %username);

  }

  push @extra_sql, '( '. join( ' OR ', @username_sql). ' )';

}

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql;

my $extra_sql = 
  scalar(@extra_sql)
    ? ' WHERE '. join(' AND ', @extra_sql )
    : '';

my $count_query = "SELECT COUNT(*) FROM svc_acct $addl_from $extra_sql";
#if ( keys %svc_acct ) {
#  $count_query .= ' WHERE '.
#                    join(' AND ', map "$_ = ". dbh->quote($svc_acct{$_}),
#                                      keys %svc_acct
#                        );
#}

my $sql_query = {
  'table' => 'svc_acct',
  'hashref'   => {}, # \%svc_acct,
  'select'    => join(', ',
                    'svc_acct.*',
                    'part_svc.svc',
                    'cust_main.custnum',
                    FS::UI::Web::cust_sql_fields(),
                  ),
  'extra_sql' => "$extra_sql $orderby",
  'addl_from' => $addl_from,
};

my $link      = [ "${p}view/svc_acct.cgi?",   'svcnum'  ];
my $link_cust = sub {
  my $svc_acct = shift;
  if ( $svc_acct->custnum ) {
    [ "${p}view/cust_main.cgi?", 'custnum' ];
  } else {
    '';
  }
};

</%init>

