<% include('/elements/header-popup.html', "$action File Attachment") %>

<% include('/elements/error.html') %>

<FORM NAME="attach_edit" ACTION="<% popurl(1) %>process/cust_main_attach.cgi" METHOD=POST ENCTYPE="multipart/form-data">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="attachnum" VALUE="<% $attachnum %>">

<BR><BR>

<TABLE BGCOLOR="#cccccc" CELLSPACING=0>
% if(defined $attach) {
%   if($curuser->access_right("Download attachment")) {
<A HREF="<% $p.'view/attachment.html?'.$attachnum %>">Download this file</A><BR>
%   }
<TR><TD> Filename </TD>
<TD><INPUT TYPE="text" NAME="filename" SIZE=40 MAXLENGTH=255 VALUE="<% $attach->filename %>"<% $disabled %>></TD></TR>
<TR><TD> Description </TD>
<TD><INPUT TYPE="text" NAME="title" SIZE=40 MAXLENGTH=80 VALUE="<% $attach->title %>"<% $disabled %></TD></TR>
<TR><TD> MIME type </TD>
<TD><INPUT TYPE="text" NAME="mime_type" VALUE="<% $attach->mime_type %>"<% $disabled %></TD></TR>
<TR><TD> Size </TD><TD><% $attach->size %></TD></TR>
% }
% else { # !defined $attach
<TR><TD> Filename </TD><TD><INPUT TYPE="file" SIZE=24 NAME="file"></TD></TR>
<TR><TD> Description </TD><TD><INPUT TYPE="text" NAME="title" SIZE=40 MAXLENGTH=80></TD></TR>
% }
</TABLE>
<BR>
% if(! $disabled) {
<INPUT TYPE="submit" NAME="submit" 
    VALUE="<% $attachnum ? "Apply Changes" : "Upload File" %>">
% }
% if(defined $attach and $curuser->access_right('Delete attachment')) {
<BR>
<INPUT TYPE="submit" NAME="delete" value="Delete File" 
onclick="return(confirm('Delete this file?'));">
% }

</FORM>
</BODY>
</HTML>

<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

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

my $action = $attachnum ? 'Edit' : 'Add';

my $disabled='';
if(! $curuser->access_right("$action attachment")) {
  $disabled = ' disabled="disabled"';
}

$cgi->param('custnum') =~ /^(\d+)$/ or die "illegal custnum";
my $custnum = $1;

</%init>

