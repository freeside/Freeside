<% include("/elements/header.html",'View Configuration', menubar( 'Main Menu' => $p,
                                     'Edit Configuration' => 'config.cgi' ) ) %>
% my $conf = new FS::Conf; my @config_items = $conf->config_items; 
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
      <td><a name="<% $i->key %>">
        <b><% $i->key %></b>&nbsp;-&nbsp;<% $i->description %>
      </a></td>
      <td><table border=0>
% foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
%             my $n = 0; 
% if ( $type eq '' ) { 

            <tr>
              <td><font color="#ff0000">no type</font></td>
            </tr>
% } elsif (   $type eq 'textarea'
%                      || $type eq 'editlist'
%                      || $type eq 'selectmultiple' ) { 

            <tr>
              <td bgcolor="#ffffff">
<pre>
<% encode_entities(join("\n", $conf->config($i->key) ) ) %>
</pre>
              </td>
            </tr>
% } elsif ( $type eq 'checkbox' ) { 

            <tr>
              <td bgcolor="#<% $conf->exists($i->key) ? '00ff00">YES' : 'ff0000">NO' %></td>
            </tr>
% } elsif ( $type eq 'text' || $type eq 'select' )  { 

            <tr>
              <td bgcolor="#ffffff">
                <% $conf->exists($i->key) ? $conf->config($i->key) : '' %>
              </td></tr>
% } elsif ( $type eq 'select-sub' ) { 

            <tr>
              <td bgcolor="#ffffff">
                <% $conf->config($i->key) %>: 
                <% &{ $i->option_sub }( $conf->config($i->key) ) %>
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
</%init>
