%if ( $error ) {
%  errorpage($error);
%} else {
%#<% $cgi->redirect(popurl(2). "browse/payment_gateway.html?showdiabled=$showdisabled") %>
<% $cgi->redirect(popurl(2). "browse/payment_gateway.html") %>
%}
<%init>

die "access deined"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#my $showdisabled = 0;
#$cgi->param('showdisabled') =~ /^(\d+)$/ and $showdisabled = $1;

#$cgi->param('gatewaynum') =~ /^(\d+)$/ or die 'illegal gatewaynum';
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ or die 'illegal gatewaynum';
my $gatewaynum = $1;

my $payment_gateway =
  qsearchs('payment_gateway', { 'gatewaynum' => $gatewaynum } );

my $error = $payment_gateway->disable;

</%init>
