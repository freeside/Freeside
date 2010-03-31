%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). 'cust_main_attach.cgi?'. $cgi->query_string ) %>
%} else {
% my $act = 'added';
% $act = 'updated' if ($attachnum);
% $act = 'purged' if($attachnum and $purge);
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

my $curuser = $FS::CurrentUser::CurrentUser;

my $delete = $cgi->param('delete');
my $undelete = $cgi->param('undelete');
my $purge = $cgi->param('purge');

my $new = new FS::cust_attachment ( {
  attachnum => $attachnum,
  custnum   => $custnum,
  _date     => time,
  usernum   => $curuser->usernum,
  disabled  => '',
});
my $old;

if($attachnum) {
  $old = qsearchs('cust_attachment', { attachnum => $attachnum });
  if(!$old) {
    $error = "Attachnum '$attachnum' not found";
  }
  elsif($purge) { # do nothing
  }
  else {
    map { $new->$_($old->$_) } 
      ('_date', 'otaker', 'body', 'disabled');
    $new->filename($cgi->param('filename') || $old->filename);
    $new->mime_type($cgi->param('mime_type') || $old->mime_type);
    $new->title($cgi->param('title'));
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
    $new->title($cgi->param('title'));
    
    local $/;
    my $fh = $cgi->upload('file');
    $new->body(<$fh>);
  }
  else {
    $error = 'No file uploaded';
  }
}
my $action = 'Add';
$action = 'Edit' if $attachnum;
$action = 'Delete' if $attachnum and $delete;
$action = 'Undelete' if $attachnum and $undelete;
$action = 'Purge' if $attachnum and $purge;

$error = 'access denied' unless $curuser->access_right($action . ' attachment');

if(!$error) {
  if($old and $old->disabled and $purge) {
    $error = $old->delete;
  }
  elsif($old) {
    $error = $new->replace($old);
  }
  else {
    $error = $new->insert;
  }
}

</%init>
