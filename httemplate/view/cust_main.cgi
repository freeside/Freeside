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

<STYLE TYPE="text/css">
.package TH { font-size: medium }
.package TR { font-size: smaller }
.package .provision { font-weight: bold }
</STYLE>

<%

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my $custnum = $1;
my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;

print qq!<A HREF="${p}edit/cust_main.cgi?$custnum">Edit this customer</A>!;

%>

<SCRIPT>
function areyousure(href, message) {
    if (confirm(message) == true)
        window.location.href = href;
}
</SCRIPT>

<%

print qq! | <A HREF="javascript:areyousure('${p}misc/cust_main-cancel.cgi?$custnum', 'Perminantly delete all services and cancel this customer?')">!.
      'Cancel this customer</A>'
  if $cust_main->ncancelled_pkgs;

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
<%= include('cust_main/order_pkg.html', $cust_main ) %>

<% if ( $conf->config('payby-default') ne 'HIDE' ) { %>
  <%= include('cust_main/quick-charge.html', $cust_main ) %>
  <BR>
<% } %>

<%= include('cust_main/packages.html', $cust_main ) %>

<% if ( $conf->config('payby-default') ne 'HIDE' ) { %>
  <%= include('cust_main/payment_history.html', $cust_main ) %>
<% } %>

</BODY></HTML>

