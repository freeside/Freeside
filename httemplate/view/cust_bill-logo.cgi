<% $conf->config_binary("logo$templatename.png", $agentnum) %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices')
      or $FS::CurrentUser::CurrentUser->access_right('View quotations')
      or $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf;

my $templatename;
my $agentnum = '';
if ( $cgi->param('invnum') =~ /^(\d+)$/ ) {
  my $invnum = $1; 
  $templatename = $cgi->param('template') || $cgi->param('templatename');
  my $cust_bill = FS::cust_bill->by_key($invnum)
               || FS::cust_bill_void->by_key($invnum)
               || die 'unknown invnum';
  $conf = $cust_bill->conf;
  $agentnum = $cust_bill->cust_main->agentnum;
} elsif ( $cgi->param('quotationnum') =~ /^(\d+)$/ ) {
  my $quotationnum = $1; 
  my $quotation = FS::quotation->by_key($quotationnum)
    or die 'unknown quotationnum';
  $conf = $quotation->conf;
  $agentnum = $quotation->agentnum;
} else {
  # assume the default config
  $conf = FS::Conf->new;
  my($query) = $cgi->keywords;
  $query =~ /^([^\.\/]*)$/ or die 'illegal query';
  $templatename = $1;
}

if ( $templatename && $conf->exists("logo_$templatename.png") ) {
  $templatename = "_$templatename";
} else {
  $templatename = '';
}

http_header('Content-Type' => 'image/png' );

</%init>
