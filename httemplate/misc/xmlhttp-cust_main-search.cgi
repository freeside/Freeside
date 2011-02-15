% if ( $sub eq 'custnum_search' ) {
% 
%   my $custnum = $cgi->param('arg');
%   my $cust_main = '';
%   if ( $custnum =~ /^(\d+)$/ and $1 <= 2147483647 ) {
%     $cust_main = qsearchs({
%       'table'   => 'cust_main',
%       'hashref' => { 'custnum' => $1 },
%       'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%     });
%   }
%   if ( ! $cust_main ) {
%     $cust_main = qsearchs({
%       'table'   => 'cust_main',
%       'hashref' => { 'agent_custid' => $custnum },
%       'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%     });
%   }
%     
"<% $cust_main ? $cust_main->name : '' %>"
%
% } elsif ( $sub eq 'smart_search' ) {
%
%   my $string = $cgi->param('arg');
%   my @cust_main = smart_search( 'search' => $string,
%                                 'no_fuzzy_on_exact' => 1, #pref?
%                               );
%   my $return = [ map [ $_->custnum, $_->name, $_->balance ], @cust_main ];
%     
<% objToJson($return) %>
% } elsif ( $sub eq 'invnum_search' ) {
%
%   my $string = $cgi->param('arg');
%   my $inv = qsearchs('cust_bill', { 'invnum' => $string });
%   my $return = [];
%   if ( $inv ) {
%   	my $cust_main = qsearchs({
%       	'table'   => 'cust_main',
%       	'hashref' => { 'custnum' => $inv->custnum },
%       	'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%     		});
%   	$return = [ $cust_main->custnum, $cust_main->name, $cust_main->balance ];
%   }
<% objToJson($return) %>
% } 
<%init>

my $conf = new FS::Conf;

my $sub = $cgi->param('sub');

</%init>
