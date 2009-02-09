<% include("/elements/header.html", $title, menubar(@menubar)) %>

Click on a configuration value to change it.
<BR><BR>

<% include('/elements/init_overlib.html') %>

% if ($FS::UID::use_confcompat) {
  <FONT SIZE="+1" COLOR="#ff0000">CONFIGURATION NOT STORED IN DATABASE -- USING COMPATIBILITY MODE</FONT><BR><BR>
%}

% foreach my $section (@sections) {

    <A NAME="<% $section || 'unclassified' %>"></A>
    <FONT SIZE="-2">

%   foreach my $nav_section (@sections) {
%
%     if ( $section eq $nav_section ) { 
        [<A NAME="not<% $nav_section || 'unclassified' %>" style="background-color: #cccccc"><% ucfirst($nav_section || 'unclassified') %></A>]
%     } else { 
        [<A HREF="#<% $nav_section || 'unclassified' %>"><% ucfirst($nav_section || 'unclassified') %></A>]
%     } 
%
%   } 

  </FONT><BR>
  <TABLE BGCOLOR="#cccccc" BORDER=1 CELLSPACING=0 CELLPADDING=0 BORDERCOLOR="#999999">
  <tr>
    <th colspan="2" bgcolor="#dcdcdc">
      <% ucfirst($section || 'unclassified') %> configuration options
    </th>
  </tr>
% foreach my $i (@{ $section_items{$section} }) { 
%   my @types = ref($i->type) ? @{$i->type} : ($i->type);
%   my( $width, $height ) = ( 522, 336 );
%   if ( grep $_ eq 'textarea', @types ) {
%     #800x600
%     $width = 763;
%     $height = 408;
%     #1024x768
%     #$width =
%     #$height = 
%   }

    <tr>
      <td><% include('/elements/popup_link.html',
                       'action'      => 'config.cgi?key='.      $i->key.
                                                  ';agentnum='. $agentnum,
                       'width'       => $width,
                       'height'      => $height,
                       'actionlabel' => 'Enter configuration value',
                       'label'       => '<b>'. $i->key. '</b>',
                       'aname'       => $i->key,
                    )
          %>: <% $i->description %>
      </td>
      <td><table border=0>

% my $n = 0;
% foreach my $type (@types) {

%   if ( $type eq '' ) { 

            <tr>
              <td><font color="#ff0000">no type</font></td>
            </tr>

%   } elsif (   $type eq 'image' ) {

            <tr>

              <% $conf->exists($i->key, $agentnum)
                   ? '<img src="config-image.cgi?key='.      $i->key.
                                               ';agentnum='. $agentnum. '">'
                   : 'empty'
              %>
            </tr>

%   } elsif (   $type eq 'binary' ) {

            <tr>

              <% $conf->exists($i->key, $agentnum)
                   ? qq!<a href="config-download.cgi?key=!. $i->key. ';agentnum='. $agentnum. qq!">download</a>!
                   : 'empty'
              %>
            </tr>

%   } elsif (    $type eq 'textarea'
%             || $type eq 'editlist'
%             || $type eq 'selectmultiple' ) { 

            <tr>
              <td id="<% $i->key.$n %>" bgcolor="#ffffff">
<font size="-2"><pre>
<% encode_entities(join("\n",
     map { length($_) > 88 ? substr($_,0,88).'...' : $_ }
         $conf->config($i->key, $agentnum)
   ) )
%>
</pre></font>
              </td>
            </tr>
%   } elsif ( $type eq 'checkbox' ) {

            <tr>
              <td id="<% $i->key.$n %>" bgcolor="#<% $conf->exists($i->key, $agentnum) ? '00ff00">YES' : 'ff0000">NO' %></td>
            </tr>
%   } elsif ( $type eq 'text' || $type eq 'select' ) {

            <tr>
              <td id="<% $i->key.$n %>" bgcolor="#ffffff">
                <% $conf->exists($i->key, $agentnum) ? $conf->config($i->key, $agentnum) : '' %>
              </td></tr>
%   } elsif ( $type eq 'select-sub' ) { 

            <tr>
              <td id="<% $i->key.$n %>" bgcolor="#ffffff">
                <% $conf->config($i->key, $agentnum) %>: 
                <% &{ $i->option_sub }( $conf->config($i->key, $agentnum) ) %>
              </td>
            </tr>
%   } else { 

            <tr><td>
              <font color="#ff0000">unknown type <% $type %></font>
            </td></tr>
%   } 
%   $n++;
% } 

      </table></td>
    </tr>
% } 

  </table><br><br>
% } 


</body></html>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agentnum = '';
my $title;
my @menubar = ();
if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  $agentnum = $1;
  my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "Agent $agentnum not found!" unless $agent;

  push @menubar, 'View all agents' => $p.'browse/agent.cgi';
  $title = 'Agent Configuration for '. $agent->agent;
} else {
  $title = 'Global Configuration';
}

my $conf = new FS::Conf;
 
my @config_items = grep { $agentnum ? $_->per_agent : 1 }
                   grep { $_->key != ~/^invoice_(html|latex|template)/ }
                        $conf->config_items; 

my @sections = qw(required billing username password UI session shell BIND );
push @sections, '', 'deprecated';

my %section_items = ();
foreach my $section (@sections) {
  $section_items{$section} = [ grep $_->section eq $section, @config_items ];
}

@sections = grep scalar( @{ $section_items{$_} } ), @sections;

</%init>
