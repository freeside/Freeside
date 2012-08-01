%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect($p. "view/cust_main.cgi?". $custnum) %>
%}
<%init>

#untaint paynum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal paynum";
my $paynum = $1;

my $cust_pay = qsearchs('cust_pay',{'paynum'=>$paynum});

my $right = 'Void payments';
$right = 'Credit card void' if $cust_pay->payby eq 'CARD';
$right = 'Echeck void'      if $cust_pay->payby eq 'CHEK';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right($right);

my $custnum = $cust_pay->custnum;

my $error = $cust_pay->void;

</%init>
