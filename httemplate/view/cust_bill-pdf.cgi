<%

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $invnum = $1;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;

http_header('Content-Type' => 'application/pdf' );
%>
<%= $cust_bill->print_pdf %>
