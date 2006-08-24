% if ( $link eq 'popup' ) { 
  <% include('/elements/header-popup.html', $title ) %>
% } else { 
  <%  include("/elements/header.html", $title, '') %>
% } 

% if ( $cgi->param('error') ) { 
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% } 

<LINK REL="stylesheet" TYPE="text/css" HREF="../elements/calendar-win2k-2.css" TITLE="win2k-2">
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar_stripped.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-en.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-setup.js"></SCRIPT>

<FORM ACTION="<% popurl(1) %>process/cust_pay.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="link" VALUE="<% $link %>">
<INPUT TYPE="hidden" NAME="linknum" VALUE="<% $linknum %>">

% unless ( $link eq 'popup' ) { 
    <% small_custview($custnum, $conf->config('countrydefault')) %>
% } 

<INPUT TYPE="hidden" NAME="payby" VALUE="<% $payby %>">

<BR><BR>
Payment
<% ntable("#cccccc", 2) %>

<TR>
  <TD ALIGN="right">Date</TD>
  <TD COLSPAN=2>
    <INPUT TYPE="text" NAME="_date" ID="_date_text" VALUE="<% time2str("%m/%d/%Y %r",$_date) %>">
    <IMG SRC="../images/calendar.png" ID="_date_button" STYLE="cursor: pointer" TITLE="Select date">
  </TD>
</TR>

<SCRIPT TYPE="text/javascript">
  Calendar.setup({
    inputField: "_date_text",
    ifFormat:   "%m/%d/%Y",
    button:     "_date_button",
    align:      "BR"
  });
</SCRIPT>

<TR>
  <TD ALIGN="right">Amount</TD>
  <TD BGCOLOR="#ffffff" ALIGN="right"><% $money_char %></TD>
  <TD><INPUT TYPE="text" NAME="paid" VALUE="<% $paid %>" SIZE=8 MAXLENGTH=8> by <B><% $payby{$payby} %></B></TD>
</TR>

% if ( $payby eq 'BILL' ) { 
  <TR>
    <TD ALIGN="right">Check #</TD>
    <TD COLSPAN=2><INPUT TYPE="text" NAME="payinfo" VALUE="<% $payinfo %>" SIZE=10></TD>
  </TR>
% } 

<TR>
% if ( $link eq 'custnum' || $link eq 'popup' ) { 

  <TD ALIGN="right">Auto-apply<BR>to invoices</TD>
  <TD COLSPAN=2>
    <SELECT NAME="apply">
      <OPTION VALUE="yes" SELECTED>yes
      <OPTION>no</SELECT>
    </TD>

% } elsif ( $link eq 'invnum' ) { 

  <TD ALIGN="right">Apply to</TD>
  <TD COLSPAN=2 BGCOLOR="#ffffff">Invoice #<B><% $linknum %></B> only</TD>
  <INPUT TYPE="hidden" NAME="apply" VALUE="no">

% } 
</TR>

</TABLE>

<INPUT TYPE="hidden" NAME="paybatch" VALUE="<% $paybatch %>">

<BR>
<INPUT TYPE="submit" VALUE="Post payment">

</FORM>
</BODY>
</HTML>

<%once>
my $conf = new FS::Conf;

my %payby = (
  'BILL' => 'Check',
  'CASH' => 'Cash',
  'WEST' => 'Western Union',
  'MCRD' => 'Manual credit card',
);

my $money_char = $conf->config('money_char') || '$';
</%once>

<%init>
my($link, $linknum, $paid, $payby, $payinfo, $_date); 
if ( $cgi->param('error') ) {
  $link     = $cgi->param('link');
  $linknum  = $cgi->param('linknum');
  $paid     = $cgi->param('paid');
  $payby    = $cgi->param('payby');
  $payinfo  = $cgi->param('payinfo');
  $_date    = $cgi->param('_date') ? str2time($cgi->param('_date')) : time;
} elsif ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $link     = $cgi->param('popup') ? 'popup' : 'custnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = $cgi->param('payby') || 'BILL';
  $payinfo  = '';
  $_date    = time;
} elsif ( $cgi->param('invnum') =~ /^(\d+)$/ ) {
  $link     = 'invnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = $cgi->param('payby') || 'BILL';
  $payinfo  = "";
  $_date    = time;
} else {
  die "illegal query ". $cgi->keywords;
}

my $paybatch = "webui-$_date-$$-". rand() * 2**32;

my $title = 'Post '. $payby{$payby}. ' payment';
$title .= " against Invoice #$linknum" if $link eq 'invnum';

my $custnum;
if ( $link eq 'invnum' ) {
  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $linknum } )
    or die "unknown invnum $linknum";
  $custnum = $cust_bill->custnum;
} elsif ( $link eq 'custnum' ) {
  $custnum = $linknum;
}
</%init>

