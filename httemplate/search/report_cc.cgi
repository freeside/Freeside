<!-- mason kludge -->
<%

my $user = getotaker;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
my $beginning = $1;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
my $ending = $1;

print header('Credit Card Recipt Report Results');

open (REPORT, "freeside-cc-receipts-report -v -s $beginning -f $ending $user |");

print '<PRE>';
while(<REPORT>) {
  print $_;
}
print '</PRE>';

print '</BODY></HTML>';

%>

