<%doc>
Quick process for toggling no_auto_apply field in cust_pay.

Requires paynum and no_auto_apply ('Y' or '') in cgi.

Requires 'Apply payment' acl.
</%doc>

% if ($error) {

<P STYLE="color: #FF0000"><% emt($error) %></P>

% } else {

<P STYLE="font-weight: bold;"><% emt($message) %></P>
<P><% emt('Please wait while the page reloads.') %></P>
<SCRIPT TYPE="text/javascript">
window.top.location.reload();
</SCRIPT>

% }

<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply payment');

my $paynum = $cgi->param('paynum');
my $noauto = $cgi->param('no_auto_apply');

my $error = '';
my $message = '';
my $cust_pay = qsearchs('cust_pay',{ paynum => $paynum });
if ($cust_pay) {
  if (($noauto eq 'Y') || (defined($noauto) && (length($noauto) == 0))) {
    $cust_pay->no_auto_apply($noauto);
    $error = $cust_pay->replace;
    $message = $noauto ?
               q(Payment will not be automatically applied to open invoices, must be applied manually) :
               q(Payment will be automatically applied to open invoices the next time this customer's payments are processed);
  } else {
    $error = 'no_auto_apply not specified';
  }
} else {
  $error .= 'Payment could not be found in database';
}


</%init>
