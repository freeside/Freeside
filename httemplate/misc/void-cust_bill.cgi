<& /elements/header-popup.html, mt('Void invoice') &>

<% include('/elements/error.html') %>

<% emt('Are you sure you want to void this invoice?') %>
<BR><BR>

<% emt("Invoice #[_1] ([_2])",$cust_bill->display_invnum, $money_char. $cust_bill->owed) %>
<BR><BR>

<FORM METHOD="POST" ACTION="process/void-cust_bill.html">
<INPUT TYPE="hidden" NAME="invnum" VALUE="<% $invnum %>">

<% ntable("#cccccc", 2) %>
<& /elements/tr-select-reason.html,
             'field'          => 'reasonnum',
             'reason_class'   => 'X',
             'cgi'            => $cgi
&>

</TABLE>

<BR>
<CENTER>
<BUTTON TYPE="submit">Yes, void invoice</BUTTON>&nbsp;&nbsp;&nbsp;\
<BUTTON TYPE="button" onClick="parent.cClick();">No, do not void invoice</BUTTON>
</CENTER>

</FORM>
</BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Void invoices');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

#untaint invnum
$cgi->param('invnum') =~ /^(\d+)$/ || die "Illegal invnum";
my $invnum = $1;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});

</%init>
