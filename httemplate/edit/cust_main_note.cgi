<% include('/elements/header-popup.html', 'Add Customer Note') %>

% if ( $cgi->param('error') ) { 
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% } 

<FORM ACTION="<% popurl(1) %>process/cust_main_note.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">


<BR><BR>
<TEXTAREA NAME="comment" ROWS="12" COLS="60">
<% $comment %>
</TEXTAREA>

<BR><BR>
<INPUT TYPE="submit" VALUE="Add note">

</FORM>
</BODY>
</HTML>

<%init>
my($custnum, $comment); 
$comment = '';

if ( $cgi->param('error') ) {
  $comment     = $cgi->param('comment');
}
$cgi->param('custnum') =~ /^(\d+)$/;
$custnum     = $1;

die "illegal query ". $cgi->keywords unless $custnum;

</%init>

