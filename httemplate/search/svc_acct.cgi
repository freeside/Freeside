<%

my $orderby = 'ORDER BY svcnum';

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors

my $cjoin = '';
my @extra_sql = ();
if ( $query =~ /^UN_(.*)$/ ) {
  $query = $1;
  $cjoin = 'LEFT JOIN cust_svc USING ( svcnum )';
  push @extra_sql, 'pkgnum IS NULL';
}

if ( $query eq 'svcnum' ) {
  #$orderby = "ORDER BY svcnum";
} elsif ( $query eq 'username' ) {
  $orderby = "ORDER BY LOWER(username)";
} elsif ( $query eq 'uid' ) {
  $orderby = "ORDER BY uid";
  push @extra_sql, "uid IS NOT NULL";
} elsif ( $cgi->param('popnum') =~ /^(\d+)$/ ) {
  push @extra_sql, "popnum = $1";
  $orderby = "ORDER BY LOWER(username)";
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  $cjoin ||= 'LEFT JOIN cust_svc USING ( svcnum )';
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

my $extra_sql = 
  scalar(@extra_sql)
    ? ' WHERE '. join(' AND ', @extra_sql )
    : '';

my $count_query = "SELECT COUNT(*) FROM svc_acct $cjoin $extra_sql";
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
                    'cust_main.custnum',
                    FS::UI::Web::cust_sql_fields(),
                  ),
  'extra_sql' => "$extra_sql $orderby",
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN part_svc  USING ( svcpart ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
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

%><%= include( 'elements/search.html',
                 'title'       => 'Account Search Results',
                 'name'        => 'accounts',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => [ '#',
                                    'Account',
                                    'UID',
                                    'Service',
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields'      => [ 'svcnum',
                                    'email',
                                    'uid',
                                    'svc',
                                    \&FS::UI::Web::cust_fields,
                                  ],
                 'links'       => [ $link,
                                    $link,
                                    $link,
                                    '',
                                    ( map { $link_cust }
                                          FS::UI::Web::cust_header()
                                    ),
                                  ],
             )
%>
