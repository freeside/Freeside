<% include('/elements/header.html', 'Generate registration codes for '. $agent->agent) %>

<% include('/elements/error.html') %>

<FORM ACTION="<%popurl(1)%>process/reg_code.cgi" METHOD="POST" NAME="OneTrueForm" onSubmit="document.OneTrueForm.submit.disabled=true">
<INPUT TYPE="hidden" NAME="agentnum" VALUE="<% $agent->agentnum %>">

Generate
% my $num = '';
% if ( $cgi->param('num') =~ /^\s*(\d+)\s*$/ ) {
%   $num = $1;
% }
<INPUT TYPE="text" NAME="num" VALUE="<% $num %>" SIZE=5 MAXLENGTH=4>
registration codes for <B><% $agent->agent %></B> allowing the following packages:
<BR><BR>

% foreach my $part_pkg ( qsearch('part_pkg', { 'disabled' => '' } ) ) { 
%   my $pkgpart = $part_pkg->pkgpart;

    <INPUT TYPE="checkbox" NAME="pkgpart<% $pkgpart %>" <% $cgi->param("pkgpart$pkgpart") ? 'CHECKED' : '' %>>
    <% $part_pkg->pkg_comment %>
    <BR>

% } 


<BR>
<INPUT TYPE="submit" NAME="submit" VALUE="Generate">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agentnum = $cgi->param('agentnum');
$agentnum =~ /^(\d+)$/ or errorpage("illegal agentnum $agentnum");
$agentnum = $1;
my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );

</%init>
