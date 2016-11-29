%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_main_note.cgi?'. $cgi->query_string ) %>
%} else {
<& /elements/popup-topreload.html, mt( 'Note '. ($notenum ? 'updated' : 'added') ) &>
% }
<%init>

$cgi->param('custnum') =~ /^(\d+)$/
  or die "Illegal custnum: ". $cgi->param('custnum');
my $custnum = $1;

$cgi->param('notenum') =~ /^(\d*)$/
  or die "Illegal notenum: ". $cgi->param('notenum');
my $notenum = $1;

$cgi->param('classnum') =~ /^(\d*)$/;
my $classnum = $1;

my $comment = $cgi->param('comment_html') || 
              join("<br />\n", 
                split "(?:\r|\n)+", $cgi->param('comment_plain')
              );

my $new = new FS::cust_main_note ( {
  notenum  => $notenum,
  custnum  => $custnum,
  classnum => $classnum ? $classnum : undef,
  _date    => time,
  usernum  => $FS::CurrentUser::CurrentUser->usernum,
  comments => $comment,
  sticky   => scalar( $cgi->param('sticky') ),
} );

my $error;
if ($notenum) {

  die "access denied"
    unless $FS::CurrentUser::CurrentUser->access_right('Edit customer note');

  my $old  = qsearchs('cust_main_note', { 'notenum' => $notenum });
  $error = "No such note: $notenum" unless $old;
  unless ($error) {
    map { $new->$_($old->$_) } ('_date', 'otaker');
    $error = $new->replace($old);
  }

} else {

  die "access denied"
    unless $FS::CurrentUser::CurrentUser->access_right('Add customer note');

  $error = $new->insert;
}

</%init>
