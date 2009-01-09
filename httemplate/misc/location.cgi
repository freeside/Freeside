<% objToJson(\%hash) %>
<%init>

my $locationnum = $cgi->param('arg');

my $cust_location = qsearchs({
  'table'     => 'cust_location',
  'hashref'   => { 'locationnum' => $locationnum },
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});

my %hash = ();
%hash = map { $_ => $cust_location->$_() }
            qw( address1 address2 city county state zip country )
  if $cust_location;

</%init>
