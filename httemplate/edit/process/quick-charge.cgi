<%

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/
  or die 'illegal custnum '. $cgi->param('custnum');
my $custnum = $1;

$cgi->param('amount') =~ /^\s*(\d+(\.\d{1,2})?)\s*$/
  or die 'illegal amount '. $cgi->param('amount');
my $amount = $1;

my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
  or die "unknown custnum $custnum";

my $error = $cust_main->charge(
  $amount,
  $cgi->param('pkg'),
  '$'. sprintf("%.2f",$amount),
  $cgi->param('taxclass')
);

if ($error) {
%>
<!-- mason kludge -->
<%
  eidiot($error);
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum" );
}

%>

