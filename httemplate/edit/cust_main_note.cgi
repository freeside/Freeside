<% include('/elements/header-popup.html', "$action Customer Note") %>

% if ( $cgi->param('error') ) { 
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% } 

<FORM ACTION="<% popurl(1) %>process/cust_main_note.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="notenum" VALUE="<% $notenum %>">


<BR><BR>
<TEXTAREA NAME="comment" ROWS="12" COLS="60">
<% $comment %>
</TEXTAREA>

<BR><BR>
<INPUT TYPE="submit" VALUE="<% $notenum ? "Apply Changes" : "Add Note" %>">

</FORM>
</BODY>
</HTML>

<%init>
my($custnum, $comment, $notenum, $action); 
$comment = '';

if ( $cgi->param('error') ) {
  $comment     = $cgi->param('comment');
}elsif ($cgi->param('notenum')) {
  $cgi->param('notenum') =~ /^(\d+)$/;
  $notenum = $1;
  die "illegal query ". $cgi->keywords unless $notenum;
  my $note = qsearchs('cust_main_note', { 'notenum' => $notenum });
  die "no such note: ". $notenum unless $note;
  $comment = $note->comments;
}

$cgi->param('notenum') =~ /^(\d+)$/;
$notenum = $1;

$cgi->param('custnum') =~ /^(\d+)$/;
$custnum     = $1;

die "illegal query ". $cgi->keywords unless $custnum;

$action = $notenum ? 'Edit' : 'Add';

</%init>

