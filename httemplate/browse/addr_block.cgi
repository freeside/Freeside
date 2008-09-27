<% include('elements/browse.html',
                'title'         => 'Address Blocks',
                'name'          => 'address block',
                'html_init'     => $html_init,
                'html_foot'     => $html_foot,
                'query'         => { 'table'     => 'addr_block',
                                     'hashref'   => {},
                                     'extra_sql' => $extra_sql,
                                     'order_by'  => $order_by,
                                   },
                'count_query'   => "SELECT count(*) from addr_block $count_sql",
                'header'        => [ 'Address Block',
                                     'Router',
                                     'Action(s)',
                                     '',
                                     '',
                                   ],
                'fields'        => [ 'NetAddr',
                                     sub { my $block = shift;
                                           my $router = $block->router;
                                           my $result = '';
                                           if ($router) {
                                             $result .= $router->routername. ' (';
                                             $result .= scalar($block->svc_broadband). ' services)';
                                           }
                                           $result;
                                         },
                                     $allocate_text,
                                     sub { shift->router ? '' : '<FONT SIZE="-2">(split)</FONT>' },
                                     sub { '<FONT SIZE="-2">('. (shift->manual_flag ? 'allow' : 'prevent'). ' automatic ip assignment)</FONT>' },
                                   ],
                'links'         => [ '',
                                     '',
                                     [ 'javascript:void(0)', '' ],
                                     $split_link,
                                     $autoassign_link,
                                   ],
                'link_onclicks' => [ '',
                                     '',
                                     $allocate_link,
                                     '',
                                   ],
                'cell_styles'   => [ '',
                                     '',
                                     'border-right:none;',
                                     'border-left:none;',
                                   ],
                'agent_virt'    => 1,
                'agent_null_right' => 'Broadband global configuration',
                'agent_pos'     => 1,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Broadband configuration')
  || $FS::CurrentUser::CurrentUser->access_right('Broadband global configuration');

my $p2 = popurl(2);
my $path = $p2 . "edit/process/addr_block";

my $extra_sql = "";

my $count_sql = "WHERE ". $FS::CurrentUser::CurrentUser->agentnums_sql(
  'null_right' => 'Broadband global configuration',
);

my $order_by = "ORDER BY ";
$order_by .= "inet(ip_gateway), " if driver_name =~ /^Pg/i;
$order_by .= "inet_aton(ip_gateway), " if driver_name =~ /^mysql/i;
$order_by .= "ip_netmask";

my $html_init = qq(
<SCRIPT>
  function addr_block_areyousure(href, word) {
    if(confirm("Are you sure you want to "+word+" this address block?") == true)
      window.location.href = href;
  }
</SCRIPT>
);

$html_init .= include('/elements/error.html');

my $confirm = sub {
  my ($verb, $num) = (shift, shift);
  "javascript:addr_block_areyousure('$path/$verb.cgi?blocknum=$num', '$verb')";
};

my $html_foot = qq(
  <FORM ACTION="$path/add.cgi" METHOD="POST">
  Gateway/Netmask: 
  <INPUT TYPE="text" NAME="ip_gateway" SIZE="15">/<INPUT TYPE="text" NAME="ip_netmask" SIZE="2">
);
$html_foot .= include( '/elements/select-agent.html',
                       'agent_virt'       => 1,
                       'agent_null_right' => 'Broadband global configuration',
                     );
$html_foot .= qq(
  <INPUT TYPE="submit" NAME="submit" VALUE="Add">
  </FORM>
);

my $allocate_text = sub { my $block = shift;
                          my $router = $block->router;
                          my $result = '';
                          if ($router) {
                            $result = '<FONT SIZE="-2">(deallocate)</FONT>'
                              unless scalar($block->svc_broadband);
                          }else{
                            $result .= '<FONT SIZE="-2">(allocate)</FONT>'
                          }
                          $result;
};

my $allocate_link = sub {
  my $block = shift;
  if ($block->router) { 
    if (scalar($block->svc_broadband) == 0) { 
      &{$confirm}('deallocate', $block->blocknum);
    } else { 
      "";
    } 
  } else { 
    include( '/elements/popup_link_onclick.html',
             'action' => "${p2}edit/allocate.html?blocknum=". $block->blocknum,
             'actionlabel' => 'Allocate block to router',
           );
  } 
}; 

my $split_link = sub {
  my $block = shift;
  my $ref = [ '', '' ];
  $ref = [ &{$confirm}('split', $block->blocknum), '' ]
    unless ($block->router);
  $ref;
}; 

my $autoassign_link = sub {
  my $block = shift;
  my $url = "$path/manual_flag.cgi?manual_flag=";
  $url .=  $block->manual_flag ? '' : 'Y';
  [ "$url;blocknum=", 'blocknum' ];
}; 

</%init>
