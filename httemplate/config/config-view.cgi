<% include("/elements/header.html",
     $title,
     menubar(
       'Main Menu' => $p,
       'View all agents' => $p.'browse/agent.cgi',
     )
   )
%>

<SCRIPT TYPE="text/javascript" SRC="<%$fsurl%>elements/overlibmws.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="<%$fsurl%>elements/overlibmws_iframe.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="<%$fsurl%>elements/overlibmws_draggable.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="<%$fsurl%>elements/iframecontentmws.js"></SCRIPT>

% if ($FS::UID::use_confcompat) {

  <FONT SIZE="+1" COLOR="#ff0000">CONFIGURATION NOT STORED IN DATABASE -- USING COMPATIBILITY MODE</FONT><BR><BR>
%}
%
% foreach my $section ( qw(required billing username password UI session
%                            shell BIND
%                           ),
%                         '', 'deprecated') { 

  <A NAME="<% $section || 'unclassified' %>"></A>
  <FONT SIZE="-2">
% foreach my $nav_section ( qw(required billing username password UI session
%                                  shell BIND
%                                 ),
%                               '', 'deprecated') { 
% if ( $section eq $nav_section ) { 

      [<A NAME="not<% $nav_section || 'unclassified' %>" style="background-color: #cccccc"><% ucfirst($nav_section || 'unclassified') %></A>]
% } else { 

      [<A HREF="#<% $nav_section || 'unclassified' %>"><% ucfirst($nav_section || 'unclassified') %></A>]
% } 
% } 

  </FONT><BR>
  <% table("#cccccc", 2) %>
  <tr>
    <th colspan="2" bgcolor="#dcdcdc">
      <% ucfirst($section || 'unclassified') %> configuration options
    </th>
  </tr>
% foreach my $i (grep $_->section eq $section, @config_items) { 

    <tr>
      <td><a href="javascript:void(0);" onClick="overlib( OLiframeContent('config.cgi?key=<% $i->key %>;agentnum=<% $agentnum %>', 522, 336, 'config_popup' ), CAPTION, 'Enter configuration value', STICKY, AUTOSTATUSCAP, MIDX, 0, MIDY, 0, DRAGGABLE, CLOSECLICK ); return false;" name="<% $i->key %>">
        <b><% $i->key %></b>&nbsp;-&nbsp;<% $i->description %>
      </a></td>
      <td><table border=0>
% foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
%             my $n = 0; 
% if ( $type eq '' ) { 

            <tr>
              <td><font color="#ff0000">no type</font></td>
            </tr>
% } elsif (   $type eq 'binary' ) {

            <tr>
              <% $conf->exists($i->key, $agentnum)
                   ? qq!<a href="config-download.cgi?key=!. $i->key. ';agentnum='. $agentnum. qq!">download</a>!
                   : 'empty'
              %>
            </tr>
% } elsif (   $type eq 'textarea'
%                      || $type eq 'editlist'
%                      || $type eq 'selectmultiple' ) { 

            <tr>
              <td bgcolor="#ffffff">
<pre>
<% encode_entities(join("\n", $conf->config($i->key, $agentnum) ) ) %>
</pre>
              </td>
            </tr>
% } elsif ( $type eq 'checkbox' ) { 

            <tr>
              <td bgcolor="#<% $conf->exists($i->key, $agentnum) ? '00ff00">YES' : 'ff0000">NO' %></td>
            </tr>
% } elsif ( $type eq 'text' || $type eq 'select' )  { 

            <tr>
              <td bgcolor="#ffffff">
                <% $conf->exists($i->key, $agentnum) ? $conf->config($i->key, $agentnum) : '' %>
              </td></tr>
% } elsif ( $type eq 'select-sub' ) { 

            <tr>
              <td bgcolor="#ffffff">
                <% $conf->config($i->key, $agentnum) %>: 
                <% &{ $i->option_sub }( $conf->config($i->key, $agentnum) ) %>
              </td>
            </tr>
% } else { 

            <tr><td>
              <font color="#ff0000">unknown type <% $type %></font>
            </td></tr>
% } 
% $n++; } 

      </table></td>
    </tr>
% } 

  </table><br><br>
% } 


</body></html>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my ($conf, $title, @config_items, $agentnum);

if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  $agentnum = $1;
}

if ($agentnum) {
  my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "Agent $agentnum not found!" unless $agent;

  $title = "Configuration for ". $agent->agent;
} else {
  $title = 'Global Configuration';
}

$conf = new FS::Conf;
@config_items = grep { $agentnum ? $_->per_agent : 1 } $conf->config_items; 

</%init>
