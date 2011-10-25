<% $content %>\
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my $legacyinvnum;
my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)(.pdf)?$/ ) { #.pdf probably not necessary anymore?
  $legacyinvnum = $1;
} else {
  $legacyinvnum = $cgi->param('legacyinvnum');
  $legacyinvnum =~ s/\.pdf//i; #probably not necessary anymore
}

my $legacy_cust_bill = qsearchs({
  'select'    => 'legacy_cust_bill.*',
  'table'     => 'legacy_cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'legacyinvnum' => $legacyinvnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Legacy invoice #$legacyinvnum not found!" unless $legacy_cust_bill;

my $content = $legacy_cust_bill->content_pdf;

#maybe should name the file after legacyid if present, but have to clean it
#my $filename = $legacy_cust_bill->legacyid

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Disposition' => "filename=$legacyinvnum.pdf" );
http_header('Content-Length' => length($content) );
#http_header('Cache-control' => 'max-age=60' );

</%init>
