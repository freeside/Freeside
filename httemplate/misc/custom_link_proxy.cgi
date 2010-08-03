% if( $response->is_success ) {
<% $response->decoded_content %>
% }
% else {
<% $response->error_as_HTML %>
% }
<%init>

my( $custnum ) = $cgi->param('custnum');
my $cust_main = qsearchs('cust_main', { custnum => $custnum } ) 
  or die "custnum '$custnum' not found"; # just check for existence

my $conf = new FS::Conf;
my $url = $conf->config('cust_main-custom_link') . $cust_main->custnum;
#warn $url;

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View customer');

my $ua = new LWP::UserAgent;
my $response = $ua->get($url);
</%init>
