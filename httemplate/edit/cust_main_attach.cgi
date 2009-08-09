<% include('/elements/header-popup.html', "$action File Attachment") %>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/cust_main_attach.cgi" METHOD=POST ENCTYPE="multipart/form-data">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="attachnum" VALUE="<% $attachnum %>">

<BR><BR>

% if(defined $attach) {
Filename <INPUT TYPE="text" NAME="filename" VALUE="<% $attach->filename %>"><BR>
MIME type <INPUT TYPE="text" NAME="mime_type" VALUE="<% $attach->mime_type %>"<BR>
Size: <% $attach->size %><BR>

% }
% else { # !defined $attach

Filename <INPUT TYPE="file" NAME="file"><BR>

% }

<BR>
<INPUT TYPE="submit" NAME="submit" 
    VALUE="<% $attachnum ? "Apply Changes" : "Upload File" %>">

% if(defined $attach) {
<BR>
<INPUT TYPE="submit" NAME="delete" value="Delete File">
% }

</FORM>
</BODY>
</HTML>

<%init>

my $attachnum = '';
my $attach;
if ( $cgi->param('error') ) {
  #$comment     = $cgi->param('comment');
} elsif ( $cgi->param('attachnum') =~ /^(\d+)$/ ) {
  $attachnum = $1;
  die "illegal query ". $cgi->keywords unless $attachnum;
  $attach = qsearchs('cust_attachment', { 'attachnum' => $attachnum });
  die "no such attachment: ". $attachnum unless $attach;
}

$cgi->param('custnum') =~ /^(\d+)$/ or die "illegal custnum";
my $custnum = $1;

my $action = $attachnum ? 'Edit' : 'Add';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right("$action customer note");

</%init>

