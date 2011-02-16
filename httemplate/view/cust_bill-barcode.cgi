<% $png %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my $conf = new FS::Conf;

die 'invalid query' unless $cgi->param('invnum');

my $cust_bill = qsearchs('cust_bill', { 'invnum' => $cgi->param('invnum') } )
or die 'unknown invnum';

my $png = $cust_bill->invoice_barcode(0);

http_header('Content-Type' => 'image/png' );

</%init>
