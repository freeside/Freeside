% if ( $sub eq 'custnum_search' ) { 
%   my $custnum = $cgi->param('arg');
%   my $return = [];
%   if ( $custnum =~ /^(\d+)$/ ) {
%	$return = findbycustnum($1,0);
%   	$return = findbycustnum($1,1) if(!scalar(@$return));
%   }
<% objToJson($return) %>
% } elsif ( $sub eq 'smart_search' ) {
%
%   my $string = $cgi->param('arg');
%   my @cust_main = smart_search( 'search' => $string,
%                                 'no_fuzzy_on_exact' => 1, #pref?
%                               );
%   my $return = [ map [ $_->custnum, $_->name, $_->balance, $_->ucfirst_status, $_->statuscolor ], @cust_main ];
%     
<% objToJson($return) %>
% } elsif ( $sub eq 'invnum_search' ) {
%
%   my $string = $cgi->param('arg');
%   my $inv = qsearchs('cust_bill', { 'invnum' => $string });
%   my $return = $inv ? findbycustnum($inv->custnum,0) : [];
<% objToJson($return) %>
% } 
<%init>

my $conf = new FS::Conf;

my $sub = $cgi->param('sub');

sub findbycustnum{
    my $custnum = shift;
    my $agent = shift;
    my $hashref = { 'custnum' => $custnum };
    $hashref = { 'agent_custid' => $custnum } if $agent;
    my $c = qsearchs({
       	'table'   => 'cust_main',
       	'hashref' => $hashref,
       	'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
     		});
   return [ $c->custnum, $c->name, $c->balance, $c->ucfirst_status, $c->statuscolor ] 
	if $c;
   [];
}
</%init>
