<% $cgi->redirect("${p}view/cust_main.cgi?$custnum") %>
<%once>

my %method = ( map { $_=>1 } qw( email print fax_invoice ) );

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

my $invnum      = $cgi->param('invnum');
my $template    = $cgi->param('template');
my $notice_name = $cgi->param('notice_name') if $cgi->param('notice_name');
my $method      = $cgi->param('method');

$method .= '_invoice' if $method eq 'fax'; #!

die "unknown method $method" unless $method{$method};

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

$cust_bill->$method({ 'template'    => $template,
                      'notice_name' => $notice_name,
                   }); 

my $custnum = $cust_bill->getfield('custnum');

</%init>
