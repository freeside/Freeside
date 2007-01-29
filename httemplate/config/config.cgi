<% include("/elements/header.html",'Edit Configuration', menubar( 'Main Menu' => $p ) ) %>
<SCRIPT>
var gSafeOnload = new Array();
var gSafeOnsubmit = new Array();
window.onload = SafeOnload;
function SafeAddOnLoad(f) {
  gSafeOnload[gSafeOnload.length] = f;
}
function SafeOnload() {
  for (var i=0;i<gSafeOnload.length;i++)
    gSafeOnload[i]();
}
function SafeAddOnSubmit(f) {
  gSafeOnsubmit[gSafeOnsubmit.length] = f;
}
function SafeOnsubmit() {
  for (var i=0;i<gSafeOnsubmit.length;i++)
    gSafeOnsubmit[i]();
}
</SCRIPT>
% my $conf = new FS::Conf; my @config_items = $conf->config_items; 


<form name="OneTrueForm" action="config-process.cgi" METHOD="POST" onSubmit="SafeOnsubmit()">
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
      <td>
% my $n = 0;
%           foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
%             #warn $i->key unless defined($type);
%        
% if ( $type eq '' ) { 


               <font color="#ff0000">no type</font>
% } elsif ( $type eq 'textarea' ) { 


               <textarea name="<% $i->key. $n %>" rows=5><% "\n". join("\n", $conf->config($i->key) ) %></textarea>
% } elsif ( $type eq 'checkbox' ) { 


               <input name="<% $i->key. $n %>" type="checkbox" value="1"<% $conf->exists($i->key) ? ' CHECKED' : '' %>>
% } elsif ( $type eq 'text' )  { 


               <input name="<% $i->key. $n %>" type="<% $type %>" value="<% $conf->exists($i->key) ? $conf->config($i->key) : '' %>">
% } elsif ( $type eq 'select' || $type eq 'selectmultiple' )  { 

          
               <select name="<% $i->key. $n %>" <% $type eq 'selectmultiple' ? 'MULTIPLE' : '' %>>
% 
%                  my %hash = ();
%                  if ( $i->select_enum ) {
%                    tie %hash, 'Tie::IxHash',
%                      '' => '', map { $_ => $_ } @{ $i->select_enum };
%                  } elsif ( $i->select_hash ) {
%                    if ( ref($i->select_hash) eq 'ARRAY' ) {
%                      tie %hash, 'Tie::IxHash',
%                        '' => '', @{ $i->select_hash };
%                    } else {
%                      tie %hash, 'Tie::IxHash',
%                        '' => '', %{ $i->select_hash };
%                    }
%                  } else {
%                    %hash = ( '' => 'WARNING: neither select_enum nor select_hash specified in Conf.pm for configuration option "'. $i->key. '"' );
%                  }
%
%                  my %saw = ();
%                  foreach my $value ( keys %hash ) {
%                    local($^W)=0; next if $saw{$value}++;
%                    my $label = $hash{$value};
%               


                    <option value="<% $value %>"<% $value eq $conf->config($i->key) || ( $type eq 'selectmultiple' && grep { $_ eq $value } $conf->config($i->key) ) ? ' SELECTED' : '' %>><% $label %>
% } 
% my $curvalue = $conf->config($i->key);
%                 if ( $conf->exists($i->key) && $curvalue
%                      && ! $hash{$curvalue}
%                    ) {
%              

              
                   <option value="<% $conf->config($i->key) %>" SELECTED><% exists( $hash{ $conf->config($i->key) } ) ? $hash{ $conf->config($i->key) } : $conf->config($i->key) %>
% } 


            </select>
% } elsif ( $type eq 'select-sub' ) { 


            <select name="<% $i->key. $n %>">
              <option value="">
% my %options = &{$i->options_sub};
%                 my @options = sort { $a <=> $b } keys %options;
%                 my %saw;
%                 foreach my $value ( @options ) {
%                    local($^W)=0; next if $saw{$value}++;
%              

                <option value="<% $value %>"<% $value eq $conf->config($i->key) ? ' SELECTED' : '' %>><% $value %>: <% $options{$value} %>
% } 
% if ( $conf->exists($i->key) && $conf->config($i->key) && ! exists $options{$conf->config($i->key)} ) { 

                <option value=<% $conf->config($i->key) %> SELECTED><% $conf->config($i->key) %>: <% &{ $i->option_sub }( $conf->config($i->key) ) %>
% } 

            </select>
% } elsif ( $type eq 'editlist' ) { 


            <script>
              function doremove<% $i->key. $n %>() {
                fromObject = document.OneTrueForm.<% $i->key. $n %>;
                for (var i=fromObject.options.length-1;i>-1;i--) {
                  if (fromObject.options[i].selected)
                    deleteOption<% $i->key. $n %>(fromObject,i);
                }
              }
              function deleteOption<% $i->key. $n %>(object,index) {
                object.options[index] = null;
              }
              function selectall<% $i->key. $n %>() {
                fromObject = document.OneTrueForm.<% $i->key. $n %>;
                for (var i=fromObject.options.length-1;i>-1;i--) {
                  fromObject.options[i].selected = true;
                }
              }
              function doadd<% $i->key. $n %>(object) {
                var myvalue = "";
% if ( defined($i->editlist_parts) ) { 
% foreach my $pnum ( 0 .. scalar(@{$i->editlist_parts})-1 ) { 


                    if ( myvalue != "" ) { myvalue = myvalue + " "; }
% if ( $i->editlist_parts->[$pnum]{type} eq 'select' ) { 

                      myvalue = myvalue + object.add<% $i->key. $n . "_$pnum" %>.options[object.add<% $i->key. $n . "_$pnum" %>.selectedIndex].value;
                      <!-- #RESET SELECT??  maybe not... -->
% } elsif ( $i->editlist_parts->[$pnum]{type} eq 'immutable' ) { 

                      myvalue = myvalue + object.add<% $i->key. $n . "_$pnum" %>.value;
% } else { 

                      myvalue = myvalue + object.add<% $i->key. $n . "_$pnum" %>.value;
                      object.add<% $i->key. $n. "_$pnum" %>.value = "";
% } 
% } 
% } else { 

                  myvalue = object.add<% $i->key. $n. "_1" %>.value;
% } 

                var optionName = new Option(myvalue, myvalue);
                var length = object.<% $i->key. $n %>.length;
                object.<% $i->key. $n %>.options[length] = optionName;
              }
            </script>
            <select multiple size=5 name="<% $i->key. $n %>">
            <option selected>----------------------------------------------------------------</option>
% foreach my $line ( $conf->config($i->key) ) { 

              <option value="<% $line %>"><% $line %></option>
% } 

            </select><br>
            <input type="button" value="remove selected" onClick="doremove<% $i->key. $n %>()">
            <script>SafeAddOnLoad(doremove<% $i->key. $n %>);
                    SafeAddOnSubmit(selectall<% $i->key. $n %>);</script>
            <br>
            <% itable() %><tr>
% if ( defined $i->editlist_parts ) { 
% my $pnum=0; foreach my $part ( @{$i->editlist_parts} ) { 

                <td>
% if ( $part->{type} eq 'text' ) { 

                  <input type="text" name="add<% $i->key. $n."_$pnum" %>">
% } elsif ( $part->{type} eq 'immutable' ) { 

                  <% $part->{value} %><input type="hidden" name="add<% $i->key. $n. "_$pnum" %>" value="<% $part->{value} %>">
% } elsif ( $part->{type} eq 'select' ) { 

                  <select name="add<% $i->key. $n. "_$pnum" %>">
% foreach my $key ( keys %{$part->{select_enum}} ) { 

                    <option value="<% $key %>"><% $part->{select_enum}{$key} %></option>
% } 

                  </select>
% } else { 

                  <font color="#ff0000">unknown type <% $part->type %></font>
% } 

                </td>
% $pnum++; } 
% } else { 

              <td><input type="text" name="add<% $i->key. $n %>_0"></td>
% } 

            <td><input type="button" value="add" onClick="doadd<% $i->key. $n %>(this.form)"></td>
            </tr></table>
% } else { 


            <font color="#ff0000">unknown type <% $type %></font>
% } 
% $n++; } 

      </td>
      <td><a name="<% $i->key %>">
        <b><% $i->key %></b> - <% $i->description %>
      </a></td>
    </tr>
% } 

  </table><br>

  You may need to restart Apache and/or freeside-queued for configuration
  changes to take effect.<br>

  <input type="submit" value="Apply changes"><br><br>
% } 


</form>

</body></html>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
</%init>
