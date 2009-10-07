<% $cgi->redirect("${p}view/cust_main.cgi?$custnum") %>
<%once>

my %method = map { $_=>1 } qw( email print fax_invoice );

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

my $statementnum = $cgi->param('statementnum');
my $template     = $cgi->param('template') || 'statement'; #XXX configure... via event??  eh..
my $notice_name  = $cgi->param('notice_name') if $cgi->param('notice_name');
my $method       = $cgi->param('method');

$method .= '_invoice' if $method eq 'fax'; #!

die "unknown method $method" unless $method{$method};

my $cust_statement = qsearchs('cust_statement',{'statementnum'=>$statementnum});
die "Can't find statement!\n" unless $cust_statement;

$cust_statement->$method({ 'template' => $template }); 

my $custnum = $cust_statement->getfield('custnum');

</%init>
