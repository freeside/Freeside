<!-- mason kludge -->
<%

my $conf = new FS::Conf;

my %uiview = ();
my %uiadd = ();
foreach my $part_svc ( qsearch('part_svc',{}) ) {
  $uiview{$part_svc->svcpart} = $p. "view/". $part_svc->svcdb . ".cgi";
  $uiadd{$part_svc->svcpart}= $p. "edit/". $part_svc->svcdb . ".cgi";
}

%>

<%= header("Customer View", menubar(
  'Main Menu' => $p,
)) %>

<%

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my $custnum = $1;
my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;

print qq!<A HREF="${p}edit/cust_main.cgi?$custnum">Edit this customer</A>!;

%>

<SCRIPT TYPE="text/javascript" SRC="../elements/overlibmws.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/overlibmws_iframe.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/overlibmws_draggable.js"></SCRIPT>

<SCRIPT TYPE="text/javascript">
function areyousure(href, message) {
  if (confirm(message) == true)
    window.location.href = href;
}
</SCRIPT>

<SCRIPT TYPE="text/javascript">

<%
my $ban = '';
if ( $cust_main->payby =~ /^(CARD|DCRD|CHEK|DCHK)$/ ) {
  $ban = '<BR><P ALIGN="center">'.
         '<INPUT TYPE="checkbox" NAME="ban" VALUE="1"> Ban this customer\\\'s ';
  if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
    $ban .= 'credit card';
  } elsif (  $cust_main->payby =~ /^(CHEK|DCHK)$/ ) {
    $ban .= 'ACH account';
  }
}
%>

var confirm_cancel = '<FORM METHOD="POST" ACTION="<%= $p %>misc/cust_main-cancel.cgi"> <INPUT TYPE="hidden" NAME="custnum" VALUE="<%= $custnum %>"> <BR><P ALIGN="center"><B>Permanently delete all services and cancel this customer?</B> <%= $ban%><BR><P ALIGN="CENTER"> <INPUT TYPE="submit" VALUE="Cancel customer">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE="BUTTON" VALUE="Don\'t cancel" onClick="cClick()"> </FORM> ';

</SCRIPT>

<% if ( $cust_main->ncancelled_pkgs ) { %>

  | <A HREF="javascript:void(0);" onClick="overlib(confirm_cancel, CAPTION, 'Confirm cancellation', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, 128, TEXTSIZE, 3, BGCOLOR, '#ff0000', CGCOLOR, '#ff0000' ); return false; ">Cancel this customer</A>

<% } %>

<%

print qq! | <A HREF="${p}misc/delete-customer.cgi?$custnum">!.
      'Delete this customer</A>'
  if $conf->exists('deletecustomers');

unless ( $conf->exists('disable_customer_referrals') ) {
  print qq! | <A HREF="!, popurl(2),
        qq!edit/cust_main.cgi?referral_custnum=$custnum">!,
        qq!Refer a new customer</A>!;

  print qq! | <A HREF="!, popurl(2),
        qq!search/cust_main.cgi?referral_custnum=$custnum">!,
        qq!View this customer's referrals</A>!;
}

print '<BR><BR>';

my $signupurl = $conf->config('signupurl');
if ( $signupurl ) {
print "This customer's signup URL: ".
      "<a href=\"$signupurl?ref=$custnum\">$signupurl?ref=$custnum</a><BR><BR>";
}

%>

<A NAME="cust_main"></A>
<%= &itable() %>
<TR>
  <TD VALIGN="top">
    <%= include('cust_main/contacts.html', $cust_main ) %>
  </TD>
  <TD VALIGN="top">
    <%= include('cust_main/misc.html', $cust_main ) %>
    <% if ( $conf->config('payby-default') ne 'HIDE' ) { %>
      <BR>
      <%= include('cust_main/billing.html', $cust_main ) %>
    <% } %>
  </TD>
</TR>
</TABLE>

<%
if ( defined $cust_main->dbdef_table->column('comments')
     && $cust_main->comments =~ /[^\s\n\r]/              ) {
%>
<BR>
Comments
<%= ntable("#cccccc") %><TR><TD><%= ntable("#cccccc",2) %>
<TR>
  <TD BGCOLOR="#ffffff">
    <PRE><%= encode_entities($cust_main->comments) %></PRE>
  </TD>
</TR>
</TABLE></TABLE>
<% } %>

<% if ( $conf->config('ticket_system') ) { %>
  <BR>
  <%= include('cust_main/tickets.html', $cust_main ) %>
<% } %>

<BR><BR>
<%= include('cust_main/packages.html', $cust_main ) %>

<% if ( $conf->config('payby-default') ne 'HIDE' ) { %>
  <%= include('cust_main/payment_history.html', $cust_main ) %>
<% } %>

</BODY></HTML>

