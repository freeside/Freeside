<% $cgi->redirect("${p}view/cust_main.cgi?$custnum") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

#untaint statementnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $template = $2 || 'statement'; #XXX configure... via event??  eh..
my $statementnum = $3;
my $cust_statement = qsearchs('cust_statement',{'statementnum'=>$statementnum});
die "Can't find statement!\n" unless $cust_statement;

$cust_statement->email($template); 

my $custnum = $cust_statement->getfield('custnum');

</%init>
