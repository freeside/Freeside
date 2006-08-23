%
%
%my $error ='';
%my $pkgnum = '';
%if ( $cgi->param('error') ) {
%  $error = $cgi->param('error');
%  $pkgnum = $cgi->param('pkgnum');
%  if ( $error eq '_bill_areyousure' ) {
%    my $bill = $cgi->param('bill');
%    $error = "You are attempting to set the next bill date to $bill, which is
%              in the past.  This will charge the customer for the interval
%              from $bill until now.  Are you sure you want to do this? ".
%           '<INPUT TYPE="checkbox" NAME="bill_areyousure" VALUE="1">';
%  }
%} else {
%  my($query) = $cgi->keywords;
%  $query =~ /^(\d+)$/ or die "no pkgnum";
%  $pkgnum = $1;
%}
%
%#get package record
%my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
%die "No package!" unless $cust_pkg;
%my $part_pkg = qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->getfield('pkgpart')});
%
%if ( $error ) {
%  #$cust_pkg->$_(str2time($cgi->param($_)) foreach qw(setup bill);
%  $cust_pkg->setup(str2time($cgi->param('setup')));
%  $cust_pkg->bill(str2time($cgi->param('bill')));
%  $cust_pkg->last_bill(str2time($cgi->param('last_bill')));
%}
%
%#my $custnum = $cust_pkg->getfield('custnum');
%


<% include("/elements/header.html",'Customer package - Edit dates') %>
%
%#, menubar(
%#  "View this customer (#$custnum)" => popurl(2). "view/cust_main.cgi?$custnum",
%#  'Main Menu' => popurl(2)
%#));
%


<LINK REL="stylesheet" TYPE="text/css" HREF="../elements/calendar-win2k-2.css" TITLE="win2k-2">
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar_stripped.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-en.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-setup.js"></SCRIPT>
%
%
%#print info
%my($susp,$cancel,$expire)=(
%  $cust_pkg->getfield('susp'),
%  $cust_pkg->getfield('cancel'),
%  $cust_pkg->getfield('expire'),
%);
%my($pkg,$comment)=($part_pkg->getfield('pkg'),$part_pkg->getfield('comment'));
%my($setup,$bill)=($cust_pkg->getfield('setup'),$cust_pkg->getfield('bill'));
%my $otaker = $cust_pkg->getfield('otaker');
%
%


<FORM NAME="formname" ACTION="process/REAL_cust_pkg.cgi" METHOD="POST">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
% if ( $error ) { 

  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $error %></FONT>
% } 
%
%
%#my $format = "%c %z (%Z)";
%my $format = "%m/%d/%Y %T %z (%Z)";
%
%#false laziness w/view/cust_main/packages.html
%#my( $billed_or_prepaid,
%my( $last_bill_or_renewed, $next_bill_or_prepaid_until );
%unless ( $part_pkg->is_prepaid ) {
%  #$billed_or_prepaid = 'billed';
%  $last_bill_or_renewed = 'Last bill';
%  $next_bill_or_prepaid_until = 'Next bill';
%} else {
%  #$billed_or_prepaid = 'prepaid';
%  $last_bill_or_renewed = 'Renewed';
%  $next_bill_or_prepaid_until = 'Prepaid until';
%}
%
%


<% ntable("#cccccc",2) %>

  <TR>
    <TD ALIGN="right">Package number</TD>
    <TD BGCOLOR="#ffffff"><% $pkgnum %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Package</TD>
    <TD BGCOLOR="#ffffff"><% $pkg %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Comment</TD>
    <TD BGCOLOR="#ffffff"><% $comment %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Order taker</TD>
    <TD BGCOLOR="#ffffff"><% $otaker %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Setup date</TD>
    <TD>
      <INPUT TYPE="text" NAME="setup" SIZE=32 ID="setup_text" VALUE="<% ( $setup ? time2str($format, $setup) : "" ) %>">
      <IMG SRC="../images/calendar.png" ID="setup_button" STYLE="cursor: pointer" TITLE="Select date">
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right"><% $last_bill_or_renewed %> date</TD>
    <TD>
      <INPUT TYPE="text" NAME="last_bill" SIZE=32 ID="last_bill_text" VALUE="<% ( $cust_pkg->last_bill ? time2str($format, $cust_pkg->last_bill) : "" ) %>">
      <IMG SRC="../images/calendar.png" ID="last_bill_button" STYLE="cursor: pointer" TITLE="Select date">
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right"><% $next_bill_or_prepaid_until %> date</TD>
    <TD>
      <INPUT TYPE="text" NAME="bill" SIZE=32 ID="bill_text" VALUE="<% ( $bill ? time2str($format, $bill) : "" ) %>">
      <IMG SRC="../images/calendar.png" ID="bill_button" STYLE="cursor: pointer" TITLE="Select date">
    </TD>
  </TR>
% if ( $susp ) { 

    <TR>
      <TD ALIGN="right">Suspension date</TD>
      <TD BGCOLOR="#ffffff"><% time2str($format, $susp) %></TD>
    </TR>
% } 


  <TR>
    <TD ALIGN="right">Expiration date</TD>
    <TD>
      <INPUT TYPE="text" NAME="expire" SIZE=32 ID="expire_text" VALUE="<% ( $expire ? time2str($format, $expire) : "" ) %>">
      <IMG SRC="../images/calendar.png" ID="expire_button" STYLE="cursor: pointer" TITLE="Select date">
      <BR><FONT SIZE=-1>(will <b>cancel</b> this package when the date is reached)</FONT>
    </TD>
  </TR>
% if ( $cancel ) { 

    <TR>
      <TD ALIGN="right">Cancellation date</TD>
      <TD BGCOLOR="#ffffff"><% time2str($format, $cancel) %></TD>
    </TR>
% } 


</TABLE>

<SCRIPT TYPE="text/javascript">
%
%  my @cal = qw( setup bill expire );
%  push @cal, 'last_bill'
%    if $cust_pkg->dbdef_table->column('last_bill');
%  foreach my $cal (@cal) {
%

  Calendar.setup({
    inputField: "<% $cal %>_text",
    ifFormat:   "%m/%d/%Y",
    button:     "<% $cal %>_button",
    align:      "BR"
  });
% } 

</SCRIPT>
<BR><INPUT TYPE="submit" VALUE="Apply Changes">
</FORM>
</BODY>
</HTML>
