<% $pdf %>
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
  $invnum =~ s/\.pdf//i; #probably not necessary anymore
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

my $pdf = $cust_bill->print_pdf(\%opt);

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Disposition' => "filename=$invnum.pdf" );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control' => 'max-age=60' );

</%init>
