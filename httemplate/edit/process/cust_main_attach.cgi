%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_main_attach.cgi?'. $cgi->query_string ) %>
%} else {
% my $act = 'added';
% $act = 'updated' if ($attachnum);
% $act = 'undeleted' if($attachnum and $undelete);
% $act = 'deleted' if($attachnum and $delete);
<% header('Attachment ' . $act ) %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
    </SCRIPT>
    </BODY></HTML>
% }
<%init>

my $error;
$cgi->param('custnum') =~ /^(\d+)$/
  or die "Illegal custnum: ". $cgi->param('custnum');
my $custnum = $1;

$cgi->param('attachnum') =~ /^(\d*)$/
  or die "Illegal attachnum: ". $cgi->param('attachnum');
my $attachnum = $1;

my $otaker = $FS::CurrentUser::CurrentUser->name;
$otaker = $FS::CurrentUser::CurrentUser->username
  if ($otaker eq "User, Legacy");

my $delete = $cgi->param('delete');
my $undelete = $cgi->param('undelete');

my $new = new FS::cust_attachment ( {
  attachnum => $attachnum,
  custnum   => $custnum,
  _date     => time,
  otaker    => $otaker,
  disabled  => '',
});
my $old;

if($attachnum) {
  $old = qsearchs('cust_attachment', { attachnum => $attachnum });
  if(!$old) {
    $error = "Attachnum '$attachnum' not found";
  }
  else {
    map { $new->$_($old->$_) } 
      ('_date', 'otaker', 'body', 'disabled');
    $new->filename($cgi->param('filename') || $old->filename);
    $new->mime_type($cgi->param('mime_type') || $old->mime_type);
    if($delete and not $old->disabled) {
      $new->disabled(time);
    }
    if($undelete and $old->disabled) {
      $new->disabled('');
    }
  }
}
else { # This is a new attachment, so require a file.

  my $filename = $cgi->param('file');
  if($filename) {
    $new->filename($filename);
    $new->mime_type($cgi->uploadInfo($filename)->{'Content-Type'});
    
    local $/;
    my $fh = $cgi->upload('file');
    $new->body(<$fh>);
  }
  else {
    $error = 'No file uploaded';
  }
}
my $user = $FS::CurrentUser::CurrentUser;

$error = 'access denied' unless $user->access_right(($old ? 'Edit' : 'Add') . ' attachment');

if(!$error) {
  if($old) {
    $error = $new->replace($old);
  }
  else {
    $error = $new->insert;
  }
}

</%init>
