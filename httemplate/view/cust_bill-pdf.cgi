<%

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)(.pdf)?$/;
my $invnum = $1;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;

my $pdf = $cust_bill->print_pdf;

http_header('Content-Type' => 'application/pdf' );
http_header('Content-Length' => length($pdf) );
http_header('Cache-control' => 'max-age=60' );
%>
<%= $pdf %>
