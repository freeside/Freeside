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
%   my @cust_main = smart_search( 'search' => $string );
%   my $return = [ map [ $_->custnum, $_->name ], @cust_main ];
%     
<% objToJson($return) %>
% } 
<%init>

my $conf = new FS::Conf;

my $sub = $cgi->param('sub');

</%init>
