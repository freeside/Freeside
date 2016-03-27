% my $title = $error ? 'Error printing and mailing invoice' : 'Invoice printed and mailed';
<% include('/elements/header-popup.html', $title ) %>
<DIV STYLE="text-align: center;">
<SPAN STYLE="color: red; font-weight: bold;"><% $error %></SPAN><BR>
<BUTTON TYPE="button" onClick="parent.cClick();">Close</BUTTON>
</DIV>
<% include('/elements/footer-popup.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Print and mail invoices');

my $invnum      = $cgi->param('invnum');

my $template    = $cgi->param('template');
my $notice_name = $cgi->param('notice_name') if $cgi->param('notice_name');
my $no_coupon   = $cgi->param('no_coupon');

#XXX agent-virt
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum})
  or die "Unknown invnum\n";

my $mode;
if ( $cgi->param('mode') =~ /^(\d+)$/ ) {
  $mode = $1;
}
$cust_bill->set('mode' => $mode) if $mode;

#these methods die instead of return errors, so, handle that without a backtrace
local $@;
my $letter_id = 
  eval { $cust_bill->postal_mail_fsinc( 'template'    => $template,
                                        'notice_name' => $notice_name,
                                        'no_coupon'   => $no_coupon,
                                      ); 
       };
my $error = "$@";

$error ||= 'Unknown print and mail error: no letter ID returned'
  unless $letter_id;

</%init>
