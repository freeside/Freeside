<% objToJson(\%hash) %>
<%init>

my $locationnum = $cgi->param('arg');

my $curuser = $FS::CurrentUser::CurrentUser;

my $cust_location = qsearchs({
  'select'    => 'cust_location.*',
  'table'     => 'cust_location',
  'hashref'   => { 'locationnum' => $locationnum },
  'addl_from' => ' LEFT JOIN cust_main     USING ( custnum     ) ',
                 ' LEFT JOIN prospect_main USING ( prospectnum ) ',
  'extra_sql' => ' AND ( '.
                       ' ( custnum IS NOT NULL AND '.
                           $curuser->agentnums_sql( table=>'cust_main' ).
                       ' ) '.
                       ' OR '.
                       ' ( prospectnum IS NOT NULL AND '.
                           $curuser->agentnums_sql( table=>'prospect_main' ).
                       ' ) '.
                     ' )',
});

my %hash = ();
%hash = map { $_ => $cust_location->$_() }
            qw( address1 address2 city county state zip country
                location_kind location_type location_number )
  if $cust_location;

</%init>
