<% include("/elements/header.html", $title, menubar(@menubar)) %>

Click on a configuration value to change it.
<BR><BR>

% unless ( $page_agent ) {
%
%   if ( $cgi->param('showagent') ) {
%     $cgi->param('showagent', 0);
      ( <a href="<% $cgi->self_url %>">hide agent overrides</a> )
%     $cgi->param('showagent', 1);
%   } else {
%     $cgi->param('showagent', 1);
      ( <a href="<% $cgi->self_url %>">show agent overrides</a> )
%     $cgi->param('showagent', 0);
%   }
%
% }
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
%
%   my @agents = ();
%   if ( $page_agent ) {
%     @agents = ( $page_agent );
%   } else {
%     @agents = (
%       '',
%       grep { defined( _config_agentonly($conf, $i->key, $_->agentnum) ) }
%            @all_agents
%     );
%   }
%
%   foreach my $agent ( @agents ) {
%     my $agentnum = $agent ? $agent->agentnum : '';
%
%     my $label = $i->key;
%     $label = '['. $agent->agent. "] $label"
%       if $agent && $cgi->param('showagent');
%
%     #indentation :/

    <tr>
      <td><% include('/elements/popup_link.html',
                       'action'      => 'config.cgi?key='.      $i->key.
                                                  ';agentnum='. $agentnum,
                       'width'       => $width,
                       'height'      => $height,
                       'actionlabel' => 'Enter configuration value',
                       'label'       => "<b>$label</b>",
                       'aname'       => $i->key, #agentnum
                                                 # if $cgi->param('showagent')?
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

%   } elsif ( $type eq 'image' ) {

            <tr>
              <td bgcolor='#ffffff'>
                <% $conf->exists($i->key, $agentnum)
                     ? '<img src="config-image.cgi?key='.      $i->key.
                                                 ';agentnum='. $agentnum. '">'
                     : 'empty'
                %>
              </td>
            </tr>
            <tr>
              <td>
                <% $conf->exists($i->key, $agentnum)
                     ? qq!<a href="config-download.cgi?key=!. $i->key. ';agentnum='. $agentnum. qq!">download</a>!
                     : ''
                %>
              </td>
            </tr>

%   } elsif ( $type eq 'binary' ) {

            <tr>
              <td>
                <% $conf->exists($i->key, $agentnum)
                     ? qq!<a href="config-download.cgi?key=!. $i->key. ';agentnum='. $agentnum. qq!">download</a>!
                     : 'empty'
                %>
              </td>
            </tr>

%   } elsif (    $type eq 'textarea'
%             || $type eq 'editlist'
%             || $type eq 'selectmultiple' ) { 

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">
<font size="-2"><pre><% encode_entities(join("\n",
     map { length($_) > 88 ? substr($_,0,88).'...' : $_ }
         $conf->config($i->key, $agentnum)
   ) )
%></pre></font>
              </td>
            </tr>

%   } elsif ( $type eq 'checkbox' ) {

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#<% $conf->exists($i->key, $agentnum) ? '00ff00">YES' : 'ff0000">NO' %></td>
            </tr>

%   } elsif ( $type eq 'select' && $i->select_hash ) {
%
%     my %hash;
%     if ( ref($i->select_hash) eq 'ARRAY' ) {
%       tie %hash, 'Tie::IxHash', '' => '', @{ $i->select_hash };
%     } else {
%       tie %hash, 'Tie::IxHash', '' => '', %{ $i->select_hash };
%     }

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">
                <% $conf->exists($i->key, $agentnum) ? $hash{ $conf->config($i->key, $agentnum) } : '' %>
              </td>
            </tr>

%   } elsif ( $type eq 'text' || $type eq 'select' ) {

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">
                <% $conf->exists($i->key, $agentnum) ? $conf->config($i->key, $agentnum) : '' %>
              </td>
            </tr>

%   } elsif ( $type eq 'select-sub' ) { 

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">
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

% } # foreach my $agentnum

% } # foreach my $i

  </table><br><br>

% } # foreach my $nav_section

</body></html>
<%once>

#should probably be a Conf method.  what else would need to use it?
sub _config_agentonly {
  my($self,$name,$agentnum)=@_;
  my $hashref = { 'name' => $name };
  $hashref->{agentnum} = $agentnum;
  local $FS::Record::conf = undef;  # XXX evil hack prevents recursion
  FS::Record::qsearchs('conf', $hashref);
}

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $page_agent = '';
my $title;
my @menubar = ();
if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  my $page_agentnum = $1;
  $page_agent = qsearchs('agent', { 'agentnum' => $page_agentnum } );
  die "Agent $page_agentnum not found!" unless $page_agent;

  push @menubar, 'View all agents' => $p.'browse/agent.cgi';
  $title = 'Agent Configuration for '. $page_agent->agent;
} else {
  $title = 'Global Configuration';
}

my $conf = new FS::Conf;
 
my @config_items = grep { $page_agent ? $_->per_agent : 1 }
                   grep { $_->key != ~/^invoice_(html|latex|template)/ }
                        $conf->config_items; 

my @sections = qw(required billing username password UI session shell BIND );
push @sections, '', 'deprecated';

my %section_items = ();
foreach my $section (@sections) {
  $section_items{$section} = [ grep $_->section eq $section, @config_items ];
}

@sections = grep scalar( @{ $section_items{$_} } ), @sections;

my @all_agents = ();
if ( $cgi->param('showagent') ) {
  @all_agents = qsearch('agent', { 'disabled' => '' } );
}
warn 'all agents: '. join('-', @all_agents);

</%init>
