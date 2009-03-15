<% include("/elements/header.html",'Generate prepaid cards'. ($agent ? ' for '. $agent->agent : '') ) %>

<% include('/elements/error.html') %>

<FORM ACTION="<%popurl(1)%>process/prepay_credit.cgi" METHOD="POST" NAME="OneTrueForm" onSubmit="document.OneTrueForm.submit.disabled=true">

Generate
<INPUT TYPE="text" NAME="num" VALUE="<% $cgi->param('num') || '(quantity)' |h %>" SIZE=10 MAXLENGTH=10 onFocus="if ( this.value == '(quantity)' ) { this.value = ''; }">

<SELECT NAME="type">
% foreach (qw(alpha alphanumeric numeric)) { 
  <OPTION<% $cgi->param('type') eq $_ ? ' SELECTED' : '' %>><% $_ %>
% } 
</SELECT>

prepaid cards

<BR>for <SELECT NAME="agentnum"><OPTION>(any agent)
% foreach my $opt_agent ( qsearch('agent', { 'disabled' => '' } ) ) { 

  <OPTION VALUE="<% $opt_agent->agentnum %>"<% $opt_agent->agentnum == $agentnum ? ' SELECTED' : '' %>><% $opt_agent->agent %>
% } 

</SELECT>

<TABLE>
<TR><TD>Value: 
$<INPUT TYPE="text" NAME="amount" SIZE=8 MAXLENGTH=7 VALUE="<% $cgi->param('amount') |h %>">
</TD>
<TD>and/or
<INPUT TYPE="text" NAME="seconds" SIZE=6 MAXLENGTH=5 VALUE="<% $cgi->param('seconds') |h %>">
<SELECT NAME="multiplier">
% foreach my $multiplier ( keys %multiplier ) { 

  <OPTION VALUE="<% $multiplier %>"<% $cgi->param('multiplier') eq $multiplier ? ' SELECTED' : '' %>><% $multiplier{$multiplier} %>
% } 

</SELECT>
</TD></TR>
<TR><TD></TD>
<TD>and/or
<INPUT TYPE="text" NAME="upbytes" SIZE=6 MAXLENGTH=5 VALUE="<% $cgi->param('upbytes') |h %>">
<SELECT NAME="upmultiplier">
% foreach my $multiplier ( keys %bytemultiplier ) { 

  <OPTION VALUE="<% $multiplier %>"<% $cgi->param('upmultiplier') eq $multiplier ? ' SELECTED' : '' %>><% $bytemultiplier{$multiplier} %>
% } 

</SELECT> upload
</TD></TR>
<TR><TD></TD>
<TD>and/or
<INPUT TYPE="text" NAME="downbytes" SIZE=6 MAXLENGTH=5 VALUE="<% $cgi->param('downbytes') |h %>">
<SELECT NAME="downmultiplier">
% foreach my $multiplier ( keys %bytemultiplier ) { 

  <OPTION VALUE="<% $multiplier %>"<% $cgi->param('downmultiplier') eq $multiplier ? ' SELECTED' : '' %>><% $bytemultiplier{$multiplier} %>
% } 

</SELECT> download
</TD></TR>
<TR><TD></TD>
<TD>and/or
<INPUT TYPE="text" NAME="totalbytes" SIZE=6 MAXLENGTH=5 VALUE="<% $cgi->param('totalbytes') |h %>">
<SELECT NAME="totalmultiplier">
% foreach my $multiplier ( keys %bytemultiplier ) { 

  <OPTION VALUE="<% $multiplier %>"<% $cgi->param('totalmultiplier') eq $multiplier ? ' SELECTED' : '' %>><% $bytemultiplier{$multiplier} %>
% } 

</SELECT> total transfer
</TD></TR>
</TABLE>
<BR><BR>
<INPUT TYPE="submit" NAME="submit" VALUE="Generate" onSubmit="this.disabled = true">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agent = '';
my $agentnum = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agent = qsearchs('agent', { 'agentnum' => $agentnum=$1 } );
}

tie my %multiplier, 'Tie::IxHash',
  1    => 'seconds',
  60   => 'minutes',
  3600 => 'hours',
;

tie my %bytemultiplier, 'Tie::IxHash',
  1          => 'bytes',
  1024       => 'Kbytes',
  1048576    => 'Mbytes',
  1073741824 => 'Gbytes',
;

$cgi->param('multiplier',     '60')      unless $cgi->param('multiplier');
$cgi->param('upmultiplier',   '1048576') unless $cgi->param('upmultiplier');
$cgi->param('downmultiplier', '1048576') unless $cgi->param('downmultiplier');
$cgi->param('totalmultiplier','1048576') unless $cgi->param('totalmultiplier');

</%init>
