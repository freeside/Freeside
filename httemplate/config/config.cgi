<!-- mason kludge -->
<%= header('Edit Configuration', menubar( 'Main Menu' => $p ) ) %>

<% my $conf = new FS::Conf; my @config_items = $conf->config_items; %>

<form action="config-process.cgi" METHOD="POST">

<% foreach my $section ( qw(required billing username password UI session
                            shell mail radius apache BIND
                           ),
                         '', 'deprecated') { %>
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
          <% } elsif ( $type eq 'select' )  { %>
            <select name="<%= $i->key. $n %>">
              <% my %saw;
                 foreach my $value ( "", @{$i->select_enum} ) {
                    local($^W)=0; next if $saw{$value}++; %>
                <option value="<%= $value %>"<%= $value eq $conf->config($i->key) ? ' SELECTED' : '' %>><%= $value %>
              <% } %>
              <% if ( $conf->exists($i->key) && $conf->config($i->key) && ! grep { $conf->config($i->key) eq $_ } @{$i->select_enum}) { %>
                <option value=<%= $conf->config($i->key) %> SELECTED><%= conf->config($i->key) %>
              <% } %>
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

You may need to restart Apache and/or freeside-queued for configuration
changes to take effect.<BR>

<input type="submit" value="Apply changes">
</form>

</body></html>
