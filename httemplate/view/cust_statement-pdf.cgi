<% $pdf %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

#untaint statementnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)(.pdf)?$/;
my $templatename = $2 || 'statement'; #XXX configure... via event??  eh..
my $statementnum = $3;

my $cust_statement = qsearchs({
  'select'    => 'cust_statement.*',
  'table'     => 'cust_statement',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'statementnum' => $statementnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Statement #$statementnum not found!" unless $cust_statement;

my $pdf = $cust_statement->print_pdf( '', $templatename);

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control' => 'max-age=60' );

</%init>
