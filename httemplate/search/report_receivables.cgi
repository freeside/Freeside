<!-- mason kludge -->
<%

my $user = getotaker;

print header('Current Receivables Report Results');

open (REPORT, "freeside-receivables-report -v $user |");

print '<PRE>';
while(<REPORT>) {
  print $_;
}
print '</PRE>';

print '</BODY></HTML>';

%>

