<%

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $templatename = $2;
my $invnum = $3;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;

http_header('Content-Type' => 'application/postscript' );
%>
<%= $cust_bill->print_ps( '', $templatename) %>
