%
%
%$cgi->param('custnum') =~ /^(\d+)$/
%  or die "Illegal custnum: ". $cgi->param('custnum');
%my $custnum = $1;
%
%$cgi->param('notenum') =~ /^(\d*)$/
%  or die "Illegal notenum: ". $cgi->param('notenum');
%my $notenum = $1;
%
%my $otaker = $FS::CurrentUser::CurrentUser->name;
%$otaker = $FS::CurrentUser::CurrentUser->username
%  if ($otaker eq "User, Legacy");
%
%my $new = new FS::cust_main_note ( {
%  notenum  => $notenum,
%  custnum  => $custnum,
%  _date    => time,
%  otaker   => $otaker,
%  comments =>  $cgi->param('comment'),
%} );
%
%my $error;
%if ($notenum){
%  my $old  = qsearchs('cust_main_note', { 'notenum' => $notenum });
%  $error = "No such note: $notenum" unless $old;
%  unless($error){
%    map { $new->$_($old->$_) } ('_date', 'otaker');
%    $error = $new->replace($old);
%  }
%}else{
%  $error = $new->insert;
%}
%
%if ($error) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). 'cust_main_note.cgi?'. $cgi->query_string );
%}
%
%    
<% header('Note ' . ($notenum ? 'updated' : 'added') ) %>
    <SCRIPT TYPE="text/javascript">
      parent.cust_main_notes.location.reload();
      try{parent.cust_main_notes.cClick()}
      catch(err){}
      try{parent.cClick()}
      catch(err){}
    </SCRIPT>
    </BODY></HTML>
%
%

