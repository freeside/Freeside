<% include('/elements/header-popup.html', 'Enter Credit') %>

<% include('/elements/error.html') %>

<FORM NAME="credit_popup" ACTION="<% $p1 %>process/cust_credit.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="crednum" VALUE="">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum |h %>">
<INPUT TYPE="hidden" NAME="paybatch" VALUE="">
<INPUT TYPE="hidden" NAME="_date" VALUE="<% $_date %>">
<INPUT TYPE="hidden" NAME="credited" VALUE="">
<INPUT TYPE="hidden" NAME="otaker" VALUE="<% $otaker %>">

<% ntable("#cccccc", 2) %>

  <TR>
    <TD ALIGN="right">Date</TD>
    <TD BGCOLOR="#ffffff"><% time2str($date_format, $_date) %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Amount</TD>
    <TD BGCOLOR="#ffffff">$<INPUT TYPE="text" NAME="amount" VALUE="<% $amount |h %>" SIZE=8 MAXLENGTH=8></TD>
  </TR>

%
%#print qq! <INPUT TYPE="checkbox" NAME="refund" VALUE="$refund">Also post refund!;
%

<% include( '/elements/tr-select-reason.html',
              'field'          => 'reasonnum',
              'reason_class'   => 'R',
              'control_button' => "document.getElementById('confirm_credit_button')",
              'cgi'            => $cgi,
           )
%>

  <TR>
    <TD ALIGN="right">Additional info</TD>
    <TD>
      <INPUT TYPE="text" NAME="addlinfo" VALUE="<% $cgi->param('addlinfo') |h %>">
    </TD>

  <TR>
    <TD ALIGN="right">Auto-apply<BR>to invoices</TD>
    <TD><SELECT NAME="apply"><OPTION VALUE="yes" SELECTED>yes<OPTION>no</SELECT></TD>
  </TR>

% if ( $conf->exists('pkg-balances') ) {
  <% include('/elements/tr-select-cust_pkg-balances.html',
               'custnum' => $custnum,
               'cgi'     => $cgi
            )
  %>
% } else {
  <INPUT TYPE="hidden" NAME="pkgnum" VALUE="">
% }

</TABLE>

<BR>

<CENTER><INPUT TYPE="submit" ID="confirm_credit_button" VALUE="Enter credit" DISABLED></CENTER>

</FORM>
</BODY>
</HTML>
<%init>

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Post credit');

my $custnum = $cgi->param('custnum');
my $amount  = $cgi->param('amount');
my $_date   = time;
my $otaker  = getotaker;
my $p1      = popurl(1);

</%init>
