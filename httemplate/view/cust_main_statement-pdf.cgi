<% $pdf %>\
<%doc>
Like view/cust_statement-pdf.cgi, but for viewing/printing the implicit 
statement containing all of a customer's invoices.  Slightly redundant.
I don't see the need to create an equivalent to view/cust_statement.html 
for this case, but one can be added if necessary.
</%doc>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $custnum = $1;

#mostly for the agent-virt, i guess.  could probably bolt it onto the cust_bill
# search
my $cust_main = qsearchs({
  'select'    => 'cust_main.*',
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
})
  or die "Customer #$custnum not found!";

my $cust_bill = qsearchs({
  'table'    => 'cust_bill',
  'hashref'  => { 'custnum' => $custnum },
  'order_by' => 'ORDER BY _date desc LIMIT 1',
})
  or die "Customer #$custnum has no invoices!";

my $cust_statement = FS::cust_statement->new({
  'custnum'       => $custnum,
#  'statementnum'  => 'ALL', #magic
  'invnum'        => $cust_bill->invnum,
  '_date'         => time,
});

my $pdf = $cust_statement->print_pdf({
  'notice_name' => 'Statement',
  'no_date'     => 1,
  'no_number'   => 1,
});

http_header('Content-Type'   => 'application/pdf' );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control'  => 'max-age=60' );

</%init>
