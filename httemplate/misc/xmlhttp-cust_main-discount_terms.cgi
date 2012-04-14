% if ( $sub eq 'discount_terms' ) {
% 
%   my $return = [];
%   my $custnum = $cgi->param('arg');
%   if ( $custnum =~ /^\d+$/ ) {
%     my $cust_main = '';
%     $cust_main = qsearchs({
%       'table'   => 'cust_main',
%       'hashref' => { 'custnum' => $custnum },
%       'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%     });
%     
%     if ($cust_main) {
%       $return = [ map [ $_, sprintf("%d months", $_) ], 
%         $cust_main->discount_terms ];
%     }
%   }
%
<% objToJson($return) %>
% } 
<%init>

my $conf = new FS::Conf;

my $sub = $cgi->param('sub');

</%init>
