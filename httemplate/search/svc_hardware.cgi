<% include('elements/search.html',
            'title'             => 'Hardware service search results',
            'name'              => 'installations',
            'query'             => $sql_query,
            'count_query'       => $count_query,
            'redirect'          => $link_svc,
            'header'            => [ '#',
                                     'Service',
                                     'Device type',
                                     'Serial #',
                                     'Hardware addr.',
                                     'IP addr.',
                                     'Smartcard',
                                     FS::UI::Web::cust_header(),
                                   ],
            'fields'            => [ 'svcnum',
                                     'svc',
                                     'model',
                                     'serial',
                                     'hw_addr',
                                     'ip_addr',
                                     'smartcard',
                                     \&FS::UI::Web::cust_fields,
                                   ],
            'links'             => [ ($link_svc) x 7,
                                     ( map { $_ ne 'Cust. Status' ? 
                                                $link_cust : '' }
                                       FS::UI::Web::cust_header() )
                                   ],
            'align'             => 'rllllll' . FS::UI::Web::cust_aligns(),
            'color'             => [ ('') x 7,
                                      FS::UI::Web::cust_colors() ],
            'style'             => [ $svc_cancel_style, ('') x 6,
                                      FS::UI::Web::cust_styles() ],
            )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');


my $addl_from = '
 LEFT JOIN cust_svc  USING ( svcnum  )
 LEFT JOIN part_svc  USING ( svcpart )
 LEFT JOIN cust_pkg  USING ( pkgnum  )
 LEFT JOIN cust_main USING ( custnum )
 LEFT JOIN hardware_type USING ( typenum )';

my @extra_sql;
push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql(
                    'null_right' => 'View/link unlinked services'
                    );

if ( $cgi->param('magic') =~ /^(unlinked)$/ ) {
  push @extra_sql, 'pkgnum IS NULL';
}

if ( lc($cgi->param('serial')) =~ /^(\w+)$/ ) {
  push @extra_sql, "LOWER(serial) LIKE '%$1%'";
}

if ( $cgi->param('hw_addr') =~ /^(\S+)$/ ) {
  my $hw_addr = uc($1);
  $hw_addr =~ s/\W//g;
  push @extra_sql, "hw_addr LIKE '%$hw_addr%'";
}

my $ip = NetAddr::IP->new($cgi->param('ip_addr'));
if ( $ip ) {
  push @extra_sql, "ip_addr = '".lc($ip->addr)."'";
}

if ( lc($cgi->param('smartcard')) =~ /^(\w+)$/ ) {
  push @extra_sql, "LOWER(smartcard) LIKE '%$1%'";
}

if ( $cgi->param('statusnum') =~ /^(\d+)$/ ) {
  push @extra_sql, "statusnum = $1";
}

if ( $cgi->param('classnum') =~ /^(\d+)$/ ) {
  push @extra_sql, "hardware_type.classnum = $1";
  if ( $cgi->param('classnum'.$1.'typenum') =~ /^(\d+)$/ ) {
    push @extra_sql, "svc_hardware.typenum = $1";
  }
}

if ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  push @extra_sql, "cust_svc.svcpart = $1";
}

my ($orderby) = $cgi->param('orderby') =~ /^(\w+( ASC| DESC)?)$/i;
$orderby ||= 'svcnum';

my $extra_sql = '';
$extra_sql = ' WHERE '.join(' AND ', @extra_sql) if @extra_sql;

my $sql_query = {
  'table'     => 'svc_hardware',
  'select'    => join(', ', 
                    'svc_hardware.*',
                    'part_svc.svc',
                    'cust_main.custnum',
                    'hardware_type.model',
                    'cust_pkg.cancel',
                    FS::UI::Web::cust_sql_fields(),
                 ),
  'hashref'   => {},
  'extra_sql' => $extra_sql,
  'order_by'  => "ORDER BY $orderby",
  'addl_from' => $addl_from,
};

my $count_query = "SELECT COUNT(*) FROM svc_hardware $addl_from $extra_sql";
my $link_svc = [ $p.'view/svc_hardware.cgi?', 'svcnum' ];
my $link_cust = [ $p.'view/cust_main.cgi?', 'custnum' ];

my $svc_cancel_style = sub {
  my $svc = shift;
  ( $svc->getfield('cancel') == 0 ) ? '' : 's';
};

</%init>
