<% include( 'elements/search.html',
                 'title'       => 'Account Search Results',
                 'name'        => 'accounts',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => \@header,
                 'fields'      => \@fields,
                 'links'       => \@links,
                 'align'       => $align,
                 'color'       => \@color,
                 'style'       => \@style,
             )
%>
<%once>

#false laziness w/ClientAPI/MyAccount.pm
sub format_time { 
  my $support = shift;
  (($support < 0) ? '-' : '' ). int(abs($support)/3600)."h".sprintf("%02d",(abs($support)%3600)/60)."m";
}

sub timelast {
  my( $svc_acct, $last, $permonth ) = @_;

  my $sql = "
    SELECT SUM(support) FROM acct_rt_transaction
      LEFT JOIN Transactions
        ON Transactions.Id = acct_rt_transaction.transaction_id
    WHERE svcnum = ? 
      AND Transactions.Created >= ?
  ";

  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( $svc_acct->svcnum,
                 time2str('%Y-%m-%d %X', time - $last*86400 ) 
               )
    or die $sth->errstr;

  my $seconds = $sth->fetchrow_arrayref->[0];

  my $return = (($seconds < 0) ? '-' : '') . concise(duration($seconds));

  $return .= sprintf(' (%.2fx)', $seconds / $permonth ) if $permonth;

  $return;

}

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

my $link      = [ "${p}view/svc_acct.cgi?",   'svcnum'  ];
my $link_cust = sub {
  my $svc_acct = shift;
  if ( $svc_acct->custnum ) {
    [ "${p}view/cust_main.cgi?", 'custnum' ];
  } else {
    '';
  }
};

my @extra_sql = ();

my @header = ( '#', 'Service', 'Account', 'UID', 'Last Login' );
my @fields = ( 'svcnum', 'svc', 'email', 'uid', 'last_login_text' );
my @links = ( $link, $link, $link, $link, $link );
my $align = 'rlllr';
my @color = ( '', '', '', '', '' );
my @style = ( '', '', '', '', '' );

if ( $cgi->param('domain') ) { 
  my $svc_domain =
    qsearchs('svc_domain', { 'domain' => $cgi->param('domain') } );
  unless ( $svc_domain ) {
    #it would be nice if this looked more like the other "not found"
    #errors, but this will do for now.
    errorpage("Domain ". $cgi->param('domain'). " not found at all");
  } else {
    push @extra_sql, 'domsvc = '. $svc_domain->svcnum;
  }
}
if ( $cgi->param('domsvc') =~ /^(\d+)$/ ) { 
  push @extra_sql, "domsvc = $1";
}

my $timepermonth = '';

my $orderby = 'ORDER BY svcnum';
if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  push @extra_sql, 'pkgnum IS NULL'
    if $cgi->param('magic') eq 'unlinked';

  my $sortby = '';
  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    $sortby = $1;
    $sortby = "LOWER($sortby)"
      if $sortby eq 'username';
    push @extra_sql, "$sortby IS NOT NULL"
      if $sortby eq 'uid' || $sortby eq 'seconds' || $sortby eq 'last_login';
    $orderby = "ORDER BY $sortby";
  }

  if ( $sortby eq 'seconds' ) {
    #push @header, 'Time remaining';
    push @header, 'Time';
    push @fields, sub { my $svc_acct = shift; format_time($svc_acct->seconds) };
    push @links, '';
    $align .= 'r';
    push @color, '';
    push @style, '';

    my $conf = new FS::Conf;
    if ( $conf->exists('svc_acct-display_paid_time_remaining') ) {
      push @header, 'Paid time', 'Last 30', 'Last 60', 'Last 90';
      push @fields,
        sub {
          my $svc_acct = shift;
          my $seconds = $svc_acct->seconds;
          my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
          my $part_pkg = $cust_pkg->part_pkg;

          #my $timepermonth = $part_pkg->option('seconds');
          $timepermonth = $part_pkg->option('seconds');
          $timepermonth = $timepermonth / $part_pkg->freq
            if $part_pkg->freq =~ /^\d+$/ && $part_pkg->freq != 0;

          #my $recur = $part_pkg->calc_recur($cust_pkg);
          my $recur = $part_pkg->base_recur($cust_pkg);

          return format_time($seconds) unless $timepermonth && $recur;

          my $balance = $cust_pkg->cust_main->balance;
          my $months_unpaid = $balance / $recur;
          my $time_unpaid = $months_unpaid * $timepermonth;
          format_time($seconds-$time_unpaid).
            sprintf(' (%.2fx monthly)', ( $seconds-$time_unpaid ) / $timepermonth );
        },
        sub { timelast( shift, 30, $timepermonth ); },
        sub { timelast( shift, 60, $timepermonth ); },
        sub { timelast( shift, 90, $timepermonth ); },
      ;
      push @links, '', '', '', '';
      $align .= 'rrrr';
      push @color, '', '', '', '';
      push @style, '', '', '', '';
    }

  }

} elsif ( $cgi->param('magic') =~ /^nologin$/ ) {

  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    my $sortby = $1;
    $sortby = "LOWER($sortby)"
      if $sortby eq 'username';
    push @extra_sql, "last_login IS NULL";
    $orderby = "ORDER BY $sortby";
  }

} elsif ( $cgi->param('magic') =~ /^advanced$/ ) {
  $orderby = "";

  if ( $cgi->param('agentnum') =~ /^(\d+)$/ and $1 ) {
    push @extra_sql, "agentnum = $1";
  }

  my $pkgpart = join (' OR cust_pkg.pkgpart=',
                      grep {$_} map { /^(\d+)$/; } ($cgi->param('pkgpart')));
  push @extra_sql,  '(cust_pkg.pkgpart=' . $pkgpart . ')' if $pkgpart;
                      
  foreach my $field (qw( last_login last_logout )) {

    my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi, $field);

    next if $beginning == 0 && $ending == 4294967295;

    if ($cgi->param($field."_invert")) {
      push @extra_sql,
        "(svc_acct.$field IS NULL OR ".
        "svc_acct.$field < $beginning AND ".
        "svc_acct.$field > $ending)";
    } else {
      push @extra_sql,
        "svc_acct.$field IS NOT NULL",
        "svc_acct.$field >= $beginning",
        "svc_acct.$field <= $ending";
    }
  
    $orderby ||= "ORDER BY svc_acct.$field" .
      ($cgi->param($field."_invert") ? ' DESC' : '');

  }

  $orderby ||= "ORDER BY svcnum";

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

push @header, FS::UI::Web::cust_header($cgi->param('cust_fields'));
push @fields, \&FS::UI::Web::cust_fields,
push @links, map { $_ ne 'Cust. Status' ? $link_cust : '' }
                 FS::UI::Web::cust_header($cgi->param('cust_fields'));
$align .= FS::UI::Web::cust_aligns();
push @color, FS::UI::Web::cust_colors();
push @style, FS::UI::Web::cust_styles();

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN part_svc  USING ( svcpart ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

#here is the agent virtualization
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql( 
                   'null_right' => 'View/link unlinked services'
                 );

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

</%init>
