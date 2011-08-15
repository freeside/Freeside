<% $ps %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my( $invnum, $template, $notice_name );
my($query) = $cgi->keywords;
if ( $query =~ /^((.+)-)?(\d+)(.pdf)?$/ ) { #probably not necessary anymore?
  $template = $2;
  $invnum = $3;
  $notice_name = 'Invoice';
} else {
  $invnum = $cgi->param('invnum');
  $template = $cgi->param('template');
  $notice_name = ( $cgi->param('notice_name') || 'Invoice' );
}

my $conf = new FS::Conf;

my %opt = (
  'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
  'template'      => $template,
  'notice_name'   => $notice_name,
);

my $cust_bill = qsearchs({
  'select'    => 'cust_bill.*',
  'table'     => 'cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'invnum' => $invnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Invoice #$invnum not found!" unless $cust_bill;

my $ps = $cust_bill->print_ps(\%opt);

http_header('Content-Type' => 'application/postscript' );
http_header('Content-Disposition' => "filename=$invnum.ps" );
http_header('Content-Length' => length($ps) );
http_header('Cache-control' => 'max-age=60' );

</%init>
