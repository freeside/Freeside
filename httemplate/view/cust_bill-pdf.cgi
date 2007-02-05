<% $pdf %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)(.pdf)?$/;
my $templatename = $2;
my $invnum = $3;

my $cust_bill = qsearchs({
  'select'    => 'cust_bill.*',
  'table'     => 'cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'invnum' => $invnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Invoice #$invnum not found!" unless $cust_bill;

my $pdf = $cust_bill->print_pdf( '', $templatename);

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control' => 'max-age=60' );

</%init>
