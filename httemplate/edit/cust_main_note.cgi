<% include('/elements/header-popup.html', "$action Customer Note") %>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/cust_main_note.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="notenum" VALUE="<% $notenum %>">

% if ($conf->exists('note-classes') && $conf->config('note-classes') > 0) {
    Class &nbsp;
	<% include( '/elements/select-table.html',
                 'table'       => 'cust_note_class',
                 'name_col'    => 'classname',
                 'curr_value'  => $classnum,
                 'empty_label' => '(none)',
                 'hashref'     => { 'disabled' => '' },
         ) %>
    <BR>
% }

% if( $FS::CurrentUser::CurrentUser->option('disable_html_editor') ) {
  <TEXTAREA NAME="comment_plain" ROWS="12" COLS="60"><% 
  join '', split /<br \/>|&nbsp;/, $comment 
  %></TEXTAREA>
% }
% else {
<% include('/elements/htmlarea.html', 'field' => 'comment_html',
                                      'curr_value' => $comment) %>
% }

<BR><BR>
<INPUT TYPE="submit" VALUE="<% $notenum ? "Apply Changes" : "Add Note" %>">

</FORM>
</BODY>
</HTML>

<%init>

my $conf = new FS::Conf;

my $comment;
my $notenum = '';
my $classnum;
if ( $cgi->param('error') ) {
  $comment     = $cgi->param('comment');
  $classnum = $cgi->param('classnum');
} elsif ( $cgi->param('notenum') =~ /^(\d+)$/ ) {
  $notenum = $1;
  die "illegal query ". $cgi->keywords unless $notenum;
  my $note = qsearchs('cust_main_note', { 'notenum' => $notenum });
  die "no such note: ". $notenum unless $note;
  $comment = $note->comments;
  $classnum = $note->classnum;
}

$comment =~ s/\r//g; # remove weird line breaks to protect FCKeditor

$cgi->param('custnum') =~ /^(\d+)$/ or die "illegal custnum";
my $custnum = $1;

my $action = $notenum ? 'Edit' : 'Add';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right("$action customer note");

</%init>

