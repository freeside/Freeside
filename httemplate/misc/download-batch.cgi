<%

http_header('Content-Type' => 'text/comma-separated-values');

for my $cust_pay_batch ( sort { $a->paybatchnum <=> $b->paybatchnum }
                              qsearch('cust_pay_batch', {} )
) {

$cust_pay_batch->exp =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
my( $mon, $y ) = ( $2, $1 );
$mon = "0$mon" if $mon < 10;
my $exp = "$mon$y";

%>
,,,,<%= $cust_pay_batch->cardnum %>,<%= $exp %>,<%= $cust_pay_batch->amount %>,<%= $cust_pay_batch->paybatchnum %>
<% } %>
