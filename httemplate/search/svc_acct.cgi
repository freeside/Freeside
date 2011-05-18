<& elements/search.html,
                 'title'       => emt('Account Search Results'),
                 'name'        => emt('accounts'),
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'redirect'    => $link,
                 'header'      => \@header,
                 'fields'      => \@fields,
                 'links'       => \@links,
                 'align'       => $align,
                 'color'       => \@color,
                 'style'       => \@style,
                 'footer'      => \@footer,
&>
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

  #my $return = (($seconds < 0) ? '-' : '') . concise(duration($seconds));
  my $return = (($seconds < 0) ? '-' : '') . format_time($seconds);

  $return .= sprintf(' (%.2fx)', $seconds / $permonth ) if $permonth;

  $return;

}

</%once>
<%init>

my $curuser =  $FS::CurrentUser::CurrentUser;

die "access denied" unless $curuser->access_right('List services');

my $link      = [ "${p}view/svc_acct.cgi?",   'svcnum'  ];
my $link_cust = sub {
  my $svc_acct = shift;
  if ( $svc_acct->custnum ) {
    [ "${p}view/cust_main.cgi?", 'custnum' ];
  } else {
    '';
  }
};

my %search_hash = ();
my @extra_sql = ();

my @header = ( 'Service', 'Account' );
my @fields = ( 'svc', 'email' );
my @links = ( $link, $link );
my $align = 'll';
my @color = ( '', '' );
my @style = ( '', '' );
my @footer = ();

my $conf = new FS::Conf;

if ( $conf->exists('report-showpasswords') #its a terrible idea
     && $curuser->access_right('List service passwords') #but if you insist...
   )
{
  push @header, emt('Password');
  push @fields, 'get_cleartext_password';
  push @links, $link;
  $align .= 'l';
  push @color, '';
  push @style, '';
}

push @header, emt('Real Name');
push @fields, 'finger';
push @links, $link;
$align .= 'l';
push @color, '';
push @style, '';

#hide the UID, its much less useful these days
if ( $cgi->param('show_uid') ) { #XXX add a checkbox
  push @header, emt('UID');
  push @fields, 'uid';
  push @links, $link;
  $align .= 'l';
  push @color, '';
  push @style, '';
}

push @header, emt('Last Login');
push @fields, 'last_login_text';
push @links, $link;
$align .= 'r';
push @color, '';
push @style, '';


for (qw( domain domsvc agentnum custnum popnum svcpart cust_fields )) {
  $search_hash{$_} = $cgi->param($_) if length($cgi->param($_));
}

my $timepermonth = '';

my $orderby = 'ORDER BY svcnum';
if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  $search_hash{'unlinked'} = 1
    if $cgi->param('magic') eq 'unlinked';

  my $sortby = '';
  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    $sortby = $1;
    $sortby = "LOWER($sortby)"
      if $sortby eq 'username';
    push @extra_sql, "$sortby IS NOT NULL" #XXX search_hash
      if $sortby eq 'uid' || $sortby eq 'seconds' || $sortby eq 'last_login';
    $orderby = "ORDER BY $sortby";
  }

  if ( $sortby eq 'seconds' ) {
    my $tot_time = 0;
    push @header, emt('Time');
    push @fields, sub { my $svc_acct = shift;
                        $tot_time += $svc_acct->seconds;
                        format_time($svc_acct->seconds);
                      };
    push @links, '';
    $align .= 'r';
    push @color, '';
    push @style, '';

    @footer = ( 'Total', '', '', '',
                sub { format_time($tot_time) }, #time
              );

    if ( $conf->exists('svc_acct-display_paid_time_remaining') ) {
      my $tot_paid_time = 0;
      my %tot = ( '30'=>0, '60'=>0, '90'=>0 );
      push @header, emt('Paid time'), emt('Last 30'), emt('Last 60'), emt('Last 90');
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
          my $periods_unpaid = $balance / $recur;
          my $time_unpaid = $periods_unpaid * $timepermonth;
          $time_unpaid *= $part_pkg->freq
            if $part_pkg->freq =~ /^\d+$/ && $part_pkg->freq != 0;
          $tot_paid_time += $seconds-$time_unpaid;
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
      push @footer, 
        sub { format_time($tot_paid_time) }, #paid time
        '', #XXX sub { $tot{'30'} }, #30
        '', #XXX sub { $tot{'60'} }, #60
        '', #XXX sub { $tot{'90'} }, #90
      ;
    }

    push @footer, '', '';

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

  $search_hash{'pkgpart'} = [ $cgi->param('pkgpart') ];

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

} elsif ( $cgi->param('popnum') ) {
  $orderby = "ORDER BY LOWER(username)";
} elsif ( $cgi->param('svcpart') ) {
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
  my $username = lc($1);

  push @username_sql, "LOWER(username) LIKE '$username'"
    if $username_type{'Exact'}
    || $username_type{'Fuzzy'};

  push @username_sql, "LOWER(username) LIKE '\%$username\%'"
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

my $date_format = $conf->config('date_format') || '%m/%d/%Y';

$cgi->param('cust_pkg_fields') =~ /^([\w\,]*)$/ or die "bad cust_pkg_fields";
my @pkg_fields = split(',', $1);
foreach my $pkg_field ( @pkg_fields ) {
  ( my $header = ucfirst($pkg_field) ) =~ s/_/ /; #:/
  push @header, $header;

  #not the most efficient to do it every field, but this is of niche use. so far
  push @fields, sub { my $svc_acct = shift;
                      my $cust_pkg = $svc_acct->cust_svc->cust_pkg or return '';
                      my $value = $cust_pkg->get($pkg_field);#closures help alot
                      $value ? time2str('%b %d %Y', $value ) : '';
                    };

  push @links, '';
  $align .= 'c';
  push @color, '';
  push @style, '';
  
}

push @header, FS::UI::Web::cust_header($cgi->param('cust_fields'));
push @fields, \&FS::UI::Web::cust_fields,
push @links, map { $_ ne 'Cust. Status' ? $link_cust : '' }
                 FS::UI::Web::cust_header($cgi->param('cust_fields'));
$align .= FS::UI::Web::cust_aligns();
push @color, FS::UI::Web::cust_colors();
push @style, FS::UI::Web::cust_styles();

$search_hash{'order_by'} = $orderby;
$search_hash{'where'} = \@extra_sql;

my $sql_query = FS::svc_acct->search(\%search_hash);
my $count_query = delete($sql_query->{'count_query'});

</%init>
