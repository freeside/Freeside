<%= header('Edit Configuration', menubar( 'Main Menu' => $p ) ) %>

<% my $conf = new FS::Conf; my @config_items = $conf->config_items; %>

<form action="config-process.cgi">

<% foreach my $section ( qw(required billing username password UI session
                            shell mail radius apache BIND
                           ),
                         '', 'depreciated') { %>
  <%= table("#cccccc", 2) %>
  <tr>
    <th colspan="2" bgcolor="#dcdcdc">
      <%= ucfirst($section || 'unclassified') %> configuration options
    </th>
  </tr>
  <% foreach my $i (grep $_->section eq $section, @config_items) { %>
    <tr>
      <td>
        <% my $n = 0;
           foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
             #warn $i->key unless defined($type);
        %>
          <% if ( $type eq '' ) { %>
            <font color="#ff0000">no type</font>
          <% } elsif ( $type eq 'textarea' ) { %>
            <textarea name="<%= $i->key. $n %>" rows=5><%= join("\n", $conf->config($i->key) ) %></textarea>
          <% } elsif ( $type eq 'checkbox' ) { %>
            <input name="<%= $i->key. $n %>" type="checkbox" value="1"<%= $conf->exists($i->key) ? ' CHECKED' : '' %>>
          <% } elsif ( $type eq 'text' )  { %>
            <input name="<%= $i->key. $n %>" type="<%= $type %>" value="<%= $conf->exists($i->key) ? $conf->config($i->key) : '' %>">
          <% } else { %>
            <font color="#ff0000">unknown type <%= $type %></font>
          <% } %>
        <% $n++; } %>
      </td>
      <td><a name="<%= $i->key %>">
        <b><%= $i->key %></b> - <%= $i->description %>
      </a></td>
    </tr>
  <% } %>
  </table><br><br>
<% } %>

<input type="submit" value="Apply changes">
</form>

</body></html>
