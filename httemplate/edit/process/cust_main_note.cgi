%
%
%$cgi->param('custnum') =~ /^(\d+)$/
%  or die "Illegal custnum: ". $cgi->param('custnum');
%my $custnum = $1;
%
%my $otaker = $FS::CurrentUser::CurrentUser->name;
%$otaker = $FS::CurrentUser::CurrentUser->username
%  if ($otaker eq "User, Legacy");
%
%my $new = new FS::cust_main_note ( {
%  custnum  => $custnum,
%  _date    => time,
%  otaker   => $otaker,
%  comments =>  $cgi->param('comment'),
%} );
%
%my $error = $new->insert;
%
%if ($error) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). 'cust_main_note.cgi?'. $cgi->query_string );
%}
%
%    
<% header('Note added') %>
    <SCRIPT TYPE="text/javascript">
      window.top.location.reload();
    </SCRIPT>

    </BODY></HTML>
%
%

