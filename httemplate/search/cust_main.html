<% include( 'elements/search.html',
                  'title'       => 'Customer Search Results', 
                  'name'        => 'customers',
                  'query'       => $sql_query,
                  'count_query' => $count_query,
                  'header'      => [ FS::UI::Web::cust_header(
                                       $cgi->param('cust_fields')
                                     ),
                                     @extra_headers,
                                   ],
                  'fields'      => [
                    \&FS::UI::Web::cust_fields,
                    @extra_fields,
                  ],
              )
%>
<%init>

die "access denied"
  unless ( $FS::CurrentUser::CurrentUser->access_right('List customers') &&
           $FS::CurrentUser::CurrentUser->access_right('List packages')
         );

my $dbh = dbh;
my $conf = new FS::Conf;
my $countrydefault = $conf->config('countrydefault');

my($query) = $cgi->keywords;

my @where = ();

##
# parse agent
##

if ( $cgi->param('agentnum') =~ /^(\d+)$/ and $1 ) {
  push @where,
    "agentnum = $1";
}

##
# parse cancelled package checkbox
##

my $pkgwhere = "";

$pkgwhere .= "AND (cancel = 0 or cancel is null)"
  unless $cgi->param('cancelled_pkgs');

my $orderby;

##
# dates
##

foreach my $field (qw( signupdate )) {

  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi, $field);

  next if $beginning == 0 && $ending == 4294967295;

  push @where,
    "cust_main.$field IS NOT NULL",
    "cust_main.$field >= $beginning",
    "cust_main.$field <= $ending";

  $orderby ||= "ORDER BY cust_main.$field";

}

##
# setup queries, subs, etc. for the search
##

$orderby ||= 'ORDER BY custnum';

# here is the agent virtualization
push @where, $FS::CurrentUser::CurrentUser->agentnums_sql;

my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

my $addl_from = 'LEFT JOIN cust_pkg USING ( custnum  ) ';

my $count_query = "SELECT COUNT(*) FROM cust_main $extra_sql";

my $select = '*';
my (@extra_headers) = ();
my (@extra_fields) = ();

if ($cgi->param('flattened_pkgs')) {

  if ($dbh->{Driver}->{Name} eq 'Pg') {

    $select .= ", array_to_string(array(select pkg from cust_pkg left join part_pkg using ( pkgpart ) where cust_main.custnum = cust_pkg.custnum $pkgwhere),'|') as magic";

  }elsif ($dbh->{Driver}->{Name} =~ /^mysql/i) {
    $select .= ", GROUP_CONCAT(pkg SEPARATOR '|') as magic";
    $addl_from .= " LEFT JOIN part_pkg using ( pkgpart )";
  }else{
    warn "warning: unknown database type ". $dbh->{Driver}->{Name}. 
         "omitting packing information from report.";
  }
  
  my $header_query = "SELECT COUNT(cust_pkg.custnum = cust_main.custnum) AS count FROM cust_main $addl_from $extra_sql $pkgwhere group by cust_main.custnum order by count desc limit 1";

  my $sth = dbh->prepare($header_query) or die dbh->errstr;
  $sth->execute() or die $sth->errstr;
  my $headerrow = $sth->fetchrow_arrayref;
  my $headercount = $headerrow ? $headerrow->[0] : 0;
  while($headercount) {
    unshift @extra_headers, "Package ". $headercount;
    unshift @extra_fields, eval q!sub {my $c = shift;
                                       my @a = split '\|', $c->magic;
                                       my $p = $a[!.--$headercount. q!];
                                       $p;
                                      };!;
  }

}

my $sql_query = {
  'table'     => 'cust_main',
  'select'    => $select,
  'hashref'   => {},
  'extra_sql' => "$extra_sql $orderby",
};


</%init>
