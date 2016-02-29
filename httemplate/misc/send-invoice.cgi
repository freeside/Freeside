% if ($cgi->param('popup')) {
%   my $title = $error ? 'Error sending invoice email' : 'Invoice email sent';
<% include('/elements/header-popup.html', $title ) %>
<DIV STYLE="text-align: center;">
<SPAN STYLE="color: red; font-weight: bold;"><% $error %></SPAN><BR>
<BUTTON TYPE="button" onClick="parent.cClick();">Close</BUTTON>
</DIV>
<% include('/elements/footer.html') %>
% } elsif ( $error ) {
%   errorpage($error);
% } else {
<% $cgi->redirect("${p}view/cust_main.cgi?$custnum") %>
% }
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
my $no_coupon   = $cgi->param('no_coupon');
my $mode;
if ( $cgi->param('mode') =~ /^(\d+)$/ ) {
  $mode = $1;
}

$method .= '_invoice' if $method eq 'fax'; #!

die "unknown method $method" unless $method{$method};

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

$cust_bill->set('mode' => $mode) if $mode;

#these methods die instead of return errors, so, handle that without a backtrace
eval { $cust_bill->$method({ 'template'    => $template,
                             'notice_name' => $notice_name,
                             'no_coupon'   => $no_coupon,
                          }); 
     };
my $error = $@;

my $custnum = $cust_bill->getfield('custnum');

</%init>
