<% $tex %>
<%init>

use File::Slurp 'slurp';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my( $invnum, $mode, $template, $notice_name );
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
  $mode = $cgi->param('mode');
}

my $conf = new FS::Conf;

my %opt = (
  'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
  'template'      => $template,
  'notice_name'   => $notice_name,
  'no_coupon'     => ($cgi->param('no_coupon') || 0)
);

my $cust_bill = qsearchs({
  'select'    => 'cust_bill.*',
  'table'     => 'cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'invnum' => $invnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Invoice #$invnum not found!" unless $cust_bill;

$cust_bill->set(mode => $mode);

my ($file) = $cust_bill->print_latex(\%opt);
my $tex = slurp("$file.tex");

http_header('Content-Type' => 'text/plain' );
http_header('Content-Disposition' => "filename=$invnum.tex" );
http_header('Content-Length' => length($tex) );
http_header('Cache-control' => 'max-age=60' );

</%init>
