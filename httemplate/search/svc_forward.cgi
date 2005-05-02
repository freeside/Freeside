<%

my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my $orderby;
if ( $query eq 'svcnum' ) {
  $orderby = 'ORDER BY svcnum';
} else {
  eidiot('unimplemented');
}

my $count_query = 'SELECT COUNT(*) FROM svc_forward';
my $sql_query = {
  'table'     => 'svc_forward',
  'hashref'   => {},
  'select'    => join(', ',
                   'svc_forward.*',
                   map "cust_main.$_", qw(custnum last first company)
                 ),
  'extra_sql' => $orderby,
  'addl_from' => 'LEFT JOIN cust_svc  USING ( svcnum  )'.
                 'LEFT JOIN cust_pkg  USING ( pkgnum  )'.
                 'LEFT JOIN cust_main USING ( custnum )',
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

%><%= include ('elements/search.html',
                 'title'             => "Mail forward Search Results",
                 'name'              => 'mail forwards',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $link,
                 'header'            => [ '#',
                                          'Mail to',
                                          'Forwards to',
                                          'Customer',
                                        ],
                 'fields'            => [ 'svcnum',
                                          $format_src,
                                          $format_dst,
                                          \&FS::svc_Common::cust_name,
                                        ],
                 'links'             => [ $link,
                                          $link_src,
                                          $link_dst,
                                          $link_cust,
                                        ],
              )
%>
