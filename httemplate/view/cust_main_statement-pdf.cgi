<%doc>
Like view/cust_statement-pdf.cgi, but for viewing/printing the implicit 
statement containing all of a customer's invoices.  Slightly redundant.
I don't see the need to create an equivalent to view/cust_statement.html 
for this case, but one can be added if necessary.
</%doc>
<% $pdf %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

#untaint statement
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $templatename = $2 || 'statement'; #XXX configure... via event??  eh..
my $custnum = $3;

my $cust_main = qsearchs({
  'select'    => 'cust_main.*',
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Customer #$custnum not found!" unless $cust_main;
my $cust_bill = ($cust_main->cust_bill)[-1]
  or die "Customer #$custnum has no invoices!";

my $cust_statement = FS::cust_statement->new({
  'custnum'       => $custnum,
#  'statementnum'  => 'ALL', #magic
  'invnum'        => $cust_bill->invnum,
  '_date'         => time,
});


my $pdf = $cust_statement->print_pdf( '', $templatename );

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control' => 'max-age=60' );

</%init>
