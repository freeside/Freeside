<!-- mason kludge -->
<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $pkgnum = $1;

#get package record
my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
die "Unknown pkgnum $pkgnum" unless $cust_pkg;
my $part_pkg = $cust_pkg->part_pkg;

my $custnum = $cust_pkg->getfield('custnum');

my $date = $cust_pkg->expire ? time2str('%D', $cust_pkg->expire) : '';

%>

<%= header('Expire package', menubar(
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
  'Main Menu' => popurl(2)
)) %>

<LINK REL="stylesheet" TYPE="text/css" HREF="../elements/calendar-win2k-2.css" TITLE="win2k-2">
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar_stripped.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-en.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-setup.js"></SCRIPT>

<%= $pkgnum %>: <%= $part_pkg->pkg. ' - '. $part_pkg->comment %>

<FORM NAME="formname" ACTION="process/expire_pkg.cgi" METHOD="post">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<%= $pkgnum %>">
<TABLE>
  <TR>
    <TD>Cancel package on </TD>
    <TD><INPUT TYPE="text" NAME="date" ID="expire_date" VALUE="<%= $date %>">
        <IMG SRC="<%= $p %>images/calendar.png" ID="expire_button" STYLE="cursor:pointer" TITLE="Select date">
        <BR><I>m/d/y</I>
    </TD>
  </TR>
</TABLE>

<SCRIPT TYPE="text/javascript">
  Calendar.setup({
    inputField: "expire_date",
    ifFormat:   "%m/%d/%Y",
    button:     "expire_button",
    align:      "BR"
  });
</SCRIPT>

<INPUT TYPE="submit" VALUE="Cancel later">
</FORM>
</BODY>
</HTML>
