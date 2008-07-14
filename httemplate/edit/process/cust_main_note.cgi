%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_main_note.cgi?'. $cgi->query_string ) %>
%} else {
<% header('Note ' . ($notenum ? 'updated' : 'added') ) %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
    </SCRIPT>
    </BODY></HTML>
% }
<%init>

$cgi->param('custnum') =~ /^(\d+)$/
  or die "Illegal custnum: ". $cgi->param('custnum');
my $custnum = $1;

$cgi->param('notenum') =~ /^(\d*)$/
  or die "Illegal notenum: ". $cgi->param('notenum');
my $notenum = $1;

my $otaker = $FS::CurrentUser::CurrentUser->name;
$otaker = $FS::CurrentUser::CurrentUser->username
  if ($otaker eq "User, Legacy");

my $new = new FS::cust_main_note ( {
  notenum  => $notenum,
  custnum  => $custnum,
  _date    => time,
  otaker   => $otaker,
  comments =>  $cgi->param('comment'),
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
