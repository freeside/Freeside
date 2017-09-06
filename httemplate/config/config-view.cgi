<% include("/elements/header.html", $title, menubar(@menubar)) %>

Click on a configuration value to change it.
<BR><BR>

% unless ( $page_agent ) {
%
%   if ( $cgi->param('showagent') ) {
%     $cgi->param('showagent', 0);
      ( <a href="<% $cgi->self_url %>">show global configuration</a> )
%     $cgi->param('showagent', 1);
%   } else {
%     $cgi->param('showagent', 1);
      ( <a href="<% $cgi->self_url %>">show agent overrides</a> )
%     $cgi->param('showagent', 0);
%   }
%
% }
% if ( @locales ) {
( 
% if ( $locale ) {
%   $cgi->delete('locale');
    <a href="<%$cgi->self_url%>">global settings</a> | 
% }
<script type='text/javascript'>
function changeLocale(what) {
  //var what = document.getElementById('select-locale');
  if(what.selectedIndex > 0) {
    what.form.submit();
  }
}
</script>
invoice language options: 
<form action="<% $cgi->self_url %>" method="GET" style="display:inline;">
<& /elements/select.html,
    'field' => 'locale',
    'options' => [ '', grep { $_ ne 'en_US'} @locales ],
    'labels'  => { map { 
        my %info = FS::Locales->locale_info($_);
        $_ => "$info{name} ($info{country})"
    } grep { $_ ne 'en_US' } @locales },
    'curr_value' => $locale,
    'id' => 'select-locale',
    'onchange' => 'changeLocale'
    &>
  )
%   $cgi->param('locale', $locale);
% }
</form>

<BR><BR>

<% include('/elements/init_overlib.html') %>

% if ($FS::UID::use_confcompat) {
  <FONT SIZE="+1" COLOR="#ff0000">CONFIGURATION NOT STORED IN DATABASE -- USING COMPATIBILITY MODE</FONT><BR><BR>
%}

% foreach my $section (@sections) {

    <A NAME="<% $section || 'misc' %>"></A>
    <FONT SIZE="-2">

%   foreach my $nav_section (@sections) {
%
%     if ( $section eq $nav_section ) { 
        <A NAME="not<% $nav_section || 'misc' %>" style="background-color: #cccccc"><% section_title($nav_section) %></A>
%     } else { 
        <A HREF="#<% $nav_section || 'misc' %>"><% section_title($nav_section) %></A>
%     } 
%
%     unless ( $nav_section eq $sections[-1] ) {
        | 
%     }
%
%   } 

  </FONT><BR>
  <TABLE BGCOLOR="#cccccc" BORDER=1 CELLSPACING=0 CELLPADDING=0 BORDERCOLOR="#999999">
  <tr>
    <th colspan="2" bgcolor="#dcdcdc">
      <% section_title($section) %>
%     if ( $curuser->option('show_confitem_counts') ) {
        (<% scalar( @{ $section_items{$section} } ) %> items)
%     }
    </th>
  </tr>
% foreach my $i (@{ $section_items{$section} }) { 
%   my @types = ref($i->type) ? @{$i->type} : ($i->type);
%#  my( $width, $height ) = ( 522, 336 );
%   my( $width, $height ) = ( 600, 336 );
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
%   my @add_agents = ();
%   if ( $page_agent ) {
%     @agents = ( $page_agent );
%   } else {
%     @agents = ( '' );
%     if ( $i->per_agent ) {
%       foreach my $agent (@all_agents) {
%         if ( defined($conf->conf( $i->key, $agent->agentnum, 1 ) ) ) {
%           push @agents, $agent;
%         } else {
%           push @add_agents, $agent;
%         }
%       }
%     }
%   }
%
%   foreach my $agent ( @agents ) {
%     my $agentnum = $agent ? $agent->agentnum : '';
%
%     next if $section eq 'deprecated'
%          && (    ! $conf->exists($i->key, $agentnum)
%               || $conf->config($i->key, $agentnum) eq ''
%             );
%
%     my $label = $i->key;
%     $label = '['. $agent->agent. "] $label"
%       if $agent && $cgi->param('showagent');
%
%     #indentation :/
%     my $action = 'config.cgi?key=' . $i->key . 
%       ";agentnum=$agentnum" . ($locale ? ";locale=$locale" : '');

    <tr>
%     unless ( $cgi->param('showagent') ) {
        <td>
          <% include('/elements/popup_link.html',
                         'action'      => $action,
                         'width'       => $width,
                         'height'      => $height,
                         'actionlabel' => 'Enter configuration value',
                         'html_label'  => "<b>$label</b>",
                         'aname'       => $i->key,
                    )
          %>: 
%     } else {
        <td><b><% $label %></b>:
%     }
                <% $i->description %>
%       if ( $agent && $cgi->param('showagent') ) {
%         my $confnum = $conf->conf( $i->key, $agent->agentnum, 1 )->confnum;
          (<A HREF="javascript:areyousure('delete this agent override', 'config-delete.cgi?confnum=<% $confnum %>;redirect=config_view_showagent')">delete agent override</A>)
%       } elsif ( $i->base_key
%                 || ( $deleteable{$i->key} && $conf->exists($i->key) ) ) {
%         my $confnum =
%           $agent
%             ? $conf->conf( $i->key, $agent->agentnum, 1 )->confnum
%             : $conf->conf( $i->key )->confnum;
%         my $showagent = $cgi->param('showagent') ? '_showagent' : '';
          (<A HREF="javascript:areyousure('delete this configuration item', 'config-delete.cgi?confnum=<% $confnum %>;redirect=config_view<%$showagent%>')">delete configuration item</A>)
%       }

      </td>
      <td><table border=0>

% my $n = 0;
% foreach my $type (@types) {

%   if ( $type eq '' ) { 

            <tr>
              <td><font color="#ff0000">no type</font></td>
            </tr>

%   } elsif ( $type eq 'image' ) {
%           my $args = 'key=' . $i->key . ";agentnum=$agentnum;locale=$locale";

            <tr>
              <td bgcolor='#ffffff'>
                <% $conf->exists($i->key, $agentnum)
                     ? '<img src="config-image.cgi?'.$args.'">'
                     : 'empty'
                %>
              </td>
            </tr>
            <tr>
              <td>
                <% $conf->exists($i->key, $agentnum)
                     ? '<a href="config-download.cgi?'.$args.'">download</a>'
                     : ''
                %>
              </td>
            </tr>

%   } elsif ( $type eq 'binary' ) {
%           my $args = 'key=' . $i->key . ";agentnum=$agentnum;locale=$locale";

            <tr>
              <td>
                <% $conf->exists($i->key, $agentnum)
                     ? '<a href="config-download.cgi?'.$args.'">download</a>'
                     : 'empty'
                %>
              </td>
            </tr>

%   } elsif (    $type eq 'textarea'
%             || $type eq 'editlist'
%             || $type eq 'selectmultiple'
%           )
%   {

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">

% my $escaped = eval { encode_entities(join("\n",
%                        map { length($_) > 88 ? substr($_,0,88).'...' : $_ }
%                          $conf->config($i->key, $agentnum)
%                      ) );
%                    };
% $escaped = $@ ? '('.encode_entities($@).')' : $escaped;
<font size="-2"><pre><% $escaped %></pre></font>

              </td>
            </tr>

%   } elsif ( $type eq 'checkbox' ) {

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#<% $conf->config_bool($i->key, $agentnum) ? '00ff00">YES' : 'ff0000">NO' %></td>
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
%               if ( $i->multiple ) {
                    <% join('<BR>',
                        map { $_ . ": " . &{ $i->option_sub }($_) }
                                            $conf->config($i->key,$agentnum)
                        )
                    %>
%               } else {
                <% $conf->config($i->key, $agentnum) %>: 
                <% &{ $i->option_sub }( $conf->config($i->key, $agentnum) ) %>
%               }
              </td>
            </tr>

%   } elsif ( $type =~ /^select-(part_svc|part_pkg|pkg_class|agent)$/ ) {
%
%     my $table = $1;
%     my $namecol = $namecol{$table};
%     my $pkey = dbdef->table($table)->primary_key;
%
%     my @keys = $conf->config($i->key, $agentnum);

            <tr>
              <td id="<% $agentnum.$i->key.$n %>" bgcolor="#ffffff">
                <% join( '<BR>',
                         map {
                           my $key = $_;
                           my $record = qsearchs($table, { $pkey => $key });
                           $record ? "$key: ".$record->$namecol() : $key;
                         } @keys
                       )
                %>
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

% if ( @add_agents ) {

  <tr>
    <td COLSPAN=2>
      <FORM>
      Add <b><% $i->key %></b> override for
        <% include('/elements/select-agent.html',
                     'agents'      => \@add_agents,
                     'empty_label' => 'Select agent',
                     'onchange'    => "agent_changed",
                     'id'          => 'agent_'. $i->key,
                  )
        %>
      agent

%     my $agent_el = "document.getElementById('agent_". $i->key. "')";
      <INPUT TYPE    = "button"
             VALUE   = "Add"
             ID      = "add_<% $i->key %>"
             DISABLED
             onClick = "<%
               include('/elements/popup_link_onclick.html',
                         'action'      =>
                           'config.cgi?key='.      $i->key.
                           ";agentnum=' + ".
                             "$agent_el.options[$agent_el.selectedIndex].value".
                             " + '",
                         'width'       => $width,
                         'height'      => $height,
                         'actionlabel' => 'Enter configuration value',
                      )
             %>"
      >
      </FORM>
    </td>
  </tr>

% } #if @add_agents

% } # foreach my $i

  </table><br><br>

% } # foreach my $nav_section

<SCRIPT TYPE="text/javascript">

  function agent_changed(what) {
    var key = what.id.substring(6); // trim agent_
    var button = document.getElementById('add_'+key);
    if ( what.selectedIndex > 0 ) {
      button.disabled = false;
    } else {
      button.disabled = true;
    }
  }

  function areyousure(what, href) {
    if ( confirm("Are you sure you want to " + what + "?") == true )
      window.location.href = href;
  }

</SCRIPT>

</body></html>
<%once>
#false laziness w/config-process.cgi
my %namecol = (
  'part_svc'  => 'svc',
  'part_pkg'  => 'pkg',
  'pkg_class' => 'classname',
  'agent'     => 'agent',
);
</%once>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied" unless $curuser->access_right('Configuration');

my $page_agent = '';
my $title;
my @menubar = ();
if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  my $page_agentnum = $1;
  $page_agent = qsearchs('agent', { 'agentnum' => $page_agentnum } );
  die "Agent $page_agentnum not found!" unless $page_agent;

  push @menubar, 'View all agents' => $p.'browse/agent.cgi';
}

my $conf = new FS::Conf;
my $conf_global = $conf;

my @locales = $conf_global->config('available-locales');

# if this is set, we are in locale mode, so limit the displayed items 
# to those with per_locale.
my $locale;
my $locale_desc;
if ( $cgi->param('locale') =~ /^\w+_\w+$/ ) {
  $locale = $cgi->param('locale');
  # and set the context on $conf
  $conf = new FS::Conf { 'locale' => $locale, 'localeonly' => 1 };
  my %locale_info = FS::Locales->locale_info($locale);
  $locale_desc = "$locale_info{name} ($locale_info{country})";

  $title = 'Invoice Configuration'; #for now it is only invoicing
  $title .= ' for '.$page_agent->agent if $page_agent;
  $title .= ', '.$locale_desc;

} elsif ($page_agent) {
  $title = 'Agent Configuration for '. $page_agent->agent;
  $title .= ", $locale_desc" if $locale;
} elsif ( $cgi->param('showagent') ) {
  $title = 'Agent Configuration Overrides'
} else {
  $title = 'Global Configuration';
}

my $show_over = $page_agent || $cgi->param('showagent');

my @config_items = grep { !defined($locale) or $_->per_locale }
                   grep { $show_over ? $_->per_agent : 1 }
                   grep { $show_over ? 1 : !$_->agentonly }
                        $conf->config_items; 

my @deleteable = qw( invoice_latexreturnaddress invoice_htmlreturnaddress );
my %deleteable = map { $_ => 1 } @deleteable;

my @sections = (qw(
    important
    billing payments payment_batching credit_cards e-checks taxation
    packages suspension cancellation
    printing print_services
      invoicing invoice_email invoice_balances invoice_templates quotations 
    notification UI addresses customer_number customer_fields reporting
    localization scalability backup
    signup self-service self-service_skinning
    API ticketing appointments network_monitoring
    services
      username password
      telephony telephony_invoicing RADIUS wireless_broadband shell BIND hosting
  ), '', qw( development deprecated )
);

my %section_items = ();
foreach my $section (@sections) {
  $section_items{$section} = [ grep $_->section eq $section, @config_items ];
}

@sections = grep scalar( @{ $section_items{$_} } ), @sections;

my @all_agents = ();
if ( $cgi->param('showagent') ) {
  @all_agents = qsearch('agent', { 'disabled' => '' } );
}

sub section_title {
  my $sec = ucfirst(shift || 'misc');
  $sec =~ s/_/ /;
  $sec;
}

</%init>
