<!-- mason kludge -->
<% 
   my $part_svc;
   my $clone = '';
   if ( $cgi->param('error') ) { #error
     $part_svc = new FS::part_svc ( {
       map { $_, scalar($cgi->param($_)) } fields('part_svc')
     } );
   } elsif ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {#clone
     #$cgi->param('clone') =~ /^(\d+)$/ or die "malformed query: $query";
     $part_svc = qsearchs('part_svc', { 'svcpart'=>$1 } )
       or die "unknown svcpart: $1";
     $clone = $part_svc->svcpart;
     $part_svc->svcpart('');
   } elsif ( $cgi->keywords ) { #edit
     my($query) = $cgi->keywords;
     $query =~ /^(\d+)$/ or die "malformed query: $query";
     $part_svc=qsearchs('part_svc', { 'svcpart'=>$1 } )
       or die "unknown svcpart: $1";
   } else { #adding
     $part_svc = new FS::part_svc {};
   }
   my $action = $part_svc->svcpart ? 'Edit' : 'Add';
   my $hashref = $part_svc->hashref;
#   my $p_svcdb = $part_svc->svcdb || 'svc_acct';


           #" onLoad=\"visualize()\""
%>

<%= header("$action Service Definition",
           menubar( 'Main Menu'         => $p,
                    'View all service definitions' => "${p}browse/part_svc.cgi"
                  ),
           )
%>

<% if ( $cgi->param('error') ) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<FORM NAME="dummy">

      Service Part #<%= $part_svc->svcpart ? $part_svc->svcpart : "(NEW)" %>
<BR><BR>
Service  <INPUT TYPE="text" NAME="svc" VALUE="<%= $hashref->{svc} %>"><BR>
Disable new orders <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<%= $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>><BR>
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<%= $hashref->{svcpart} %>">
<BR>
Services are items you offer to your customers.
<UL><LI>svc_acct - Shell accounts, POP mailboxes, SLIP/PPP and ISDN accounts
    <LI>svc_domain - Domains
    <LI>svc_acct_sm - <B>deprecated</B> (use svc_forward for new installations) Virtual domain mail aliasing.
    <LI>svc_forward - mail forwarding
    <LI>svc_www - Virtual domain website
    <LI>svc_broadband - Broadband/High-speed Internet service
<!--   <LI>svc_charge - One-time charges (Partially unimplemented)
       <LI>svc_wo - Work orders (Partially unimplemented)
-->
</UL>
For the selected table, you can give fields default or fixed (unchangable)
values.  For example, a SLIP/PPP account may have a default (or perhaps fixed)
<B>slipip</B> of <B>0.0.0.0</B>, while a POP mailbox will probably have a fixed
blank <B>slipip</B> as well as a fixed shell something like <B>/bin/true</B> or
<B>/usr/bin/passwd</B>.
<BR><BR>

<%
#these might belong somewhere else for other user interfaces 
#pry need to eventually create stuff that's shared amount UIs
my %defs = (
  'svc_acct' => {
    'dir'       => 'Home directory',
    'uid'       => 'UID (set to fixed and blank for dial-only)',
    'slipip'    => 'IP address (Set to fixed and blank to disable dialin, or, set a value to be exported to RADIUS Framed-IP-Address.  Use the special value <code>0e0</code> [zero e zero] to enable export to RADIUS without a Framed-IP-Address.)',
#    'popnum'    => qq!<A HREF="$p/browse/svc_acct_pop.cgi/">POP number</A>!,
    'popnum'    => {
                     desc => 'Access number',
                     type => 'select',
                     select_table => 'svc_acct_pop',
                     select_key   => 'popnum',
                     select_label => 'city',
                   },
    'username'  => 'Username',
    'quota'     => '',
    '_password' => 'Password',
    'gid'       => 'GID (when blank, defaults to UID)',
    'shell'     => 'Shell (all service definitions should have a default or fixed shell that is present in the <b>shells</b> configuration file)',
    'finger'    => 'GECOS',
    'domsvc'    => {
                     desc =>'svcnum from svc_domain',
                     type =>'select',
                     select_table => 'svc_domain',
                     select_key   => 'svcnum',
                     select_label => 'domain',
                   },
    'usergroup' => {
                     desc =>'ICRADIUS/FreeRADIUS groups',
                     type =>'radius_usergroup_selector',
                   },
  },
  'svc_domain' => {
    'domain'    => 'Domain',
  },
  'svc_acct_sm' => {
    'domuser'   => 'domuser@virtualdomain.com',
    'domuid'    => 'UID where domuser@virtualdomain.com mail is forwarded',
    'domsvc'    => 'svcnum from svc_domain for virtualdomain.com',
  },
  'svc_forward' => {
    'srcsvc'    => 'service from which mail is to be forwarded',
    'dstsvc'    => 'service to which mail is to be forwarded',
    'dst'       => 'someone@another.domain.com to use when dstsvc is 0',
  },
  'svc_charge' => {
    'amount'    => 'amount',
  },
  'svc_wo' => {
    'worker'    => 'Worker',
    '_date'      => 'Date',
  },
  'svc_www' => {
    #'recnum' => '',
    #'usersvc' => '',
  },
  'svc_broadband' => {
    'actypenum' => 'This is the actypenum that refers to the type of AC that can be provisioned for this service.  This field must be set fixed.',
    'speed_down' => 'Maximum download speed for this service in Kbps.  0 denotes unlimited.',
    'speed_up' => 'Maximum upload speed for this service in Kbps.  0 denotes unlimited.',
    'acnum' => 'acnum of a specific AC that this service is restricted to.  Not required',
    'ip_addr' => 'IP address.  Leave blank for automatic assignment.',
    'ip_netmask' => 'Mask length, aka. netmask bits.  (Eg. 255.255.255.0 == 24)',
    'mac_addr' => 'MAC address which is used by some ACs for access control.  Specified by 6 colon seperated hex octets. (Eg. 00:00:0a:bc:1a:2b)',
    'location' => 'Defines the physically location at which this service was installed.  This is not necessarily the billing address',
  },
);

  my @dbs = $hashref->{svcdb}
             ? ( $hashref->{svcdb} )
             : qw( svc_acct svc_domain svc_acct_sm svc_forward svc_www svc_broadband );

  tie my %svcdb, 'Tie::IxHash', map { $_=>$_ } @dbs;
  my $widget = new HTML::Widgets::SelectLayers(
    #'selected_layer' => $p_svcdb,
    'selected_layer' => $hashref->{svcdb} || 'svc_acct',
    'options'        => \%svcdb,
    'form_name'      => 'dummy',
    'form_action'    => 'process/part_svc.cgi',
    'form_text'      => [ qw( svc svcpart ) ],
    'form_checkbox'  => [ 'disabled' ],
    'layer_callback' => sub {
      my $layer = shift;
      my $html = qq!<INPUT TYPE="hidden" NAME="svcdb" VALUE="$layer">!;

      my $columns = 3;
      my $count = 0;
      my @part_export =
        map { qsearch( 'part_export', {exporttype => $_ } ) }
          keys %{FS::part_export::export_info($layer)};
     $html .= '<BR><BR>'. table().
               table(). "<TR><TH COLSPAN=$columns>Exports</TH></TR><TR>";
      foreach my $part_export ( @part_export ) {
        $html .= '<TD><INPUT TYPE="checkbox"'.
                 ' NAME="exportnum'. $part_export->exportnum. '"  VALUE="1" ';
        $html .= 'CHECKED'
          if qsearchs( 'export_svc', {
                                   exportnum => $part_export->exportnum,
                                   svcpart   => $clone || $part_svc->svcpart });
        $html .= '> '. $part_export->exporttype. ' to '. $part_export->machine.
                 '</TD>';
        $count++;
        $html .= '</TR><TR>' unless $count % $columns;
      }
      $html .= '</TR></TABLE><BR><BR>';

      $html .=  table(). "<TH>Field</TH><TH COLSPAN=2>Modifier</TH>";
      #yucky kludge
      my @fields = defined( $FS::Record::dbdef->table($layer) )
                      ? grep { $_ ne 'svcnum' } fields($layer)
                      : ();
      push @fields, 'usergroup' if $layer eq 'svc_acct'; #kludge
      $part_svc->svcpart($clone) if $clone; #haha, undone below
      foreach my $field (@fields) {
        my $part_svc_column = $part_svc->part_svc_column($field);
        my $value = $cgi->param('error')
                      ? $cgi->param("${layer}__${field}")
                      : $part_svc_column->columnvalue;
        my $flag = $cgi->param('error')
                     ? $cgi->param("${layer}__${field}_flag")
                     : $part_svc_column->columnflag;
        my $def = $defs{$layer}{$field};
        my $desc = ref($def) ? $def->{desc} : $def;
        
        $html .= "<TR><TD>$field";
        $html .= "- <FONT SIZE=-1>$desc</FONT>" if $desc;
        $html .=  "</TD>";
        $html .=
          qq!<TD><INPUT TYPE="radio" NAME="${layer}__${field}_flag" VALUE=""!.
          ' CHECKED'x($flag eq ''). ">Off</TD>".
          qq!<TD><INPUT TYPE="radio" NAME="${layer}__${field}_flag" VALUE="D"!.
          ' CHECKED'x($flag eq 'D'). ">Default ".
          qq!<INPUT TYPE="radio" NAME="${layer}__${field}_flag" VALUE="F"!.
          ' CHECKED'x($flag eq 'F'). ">Fixed ".
          '<BR>';
        if ( ref($def) ) {
          if ( $def->{type} eq 'select' ) {
            $html .= qq!<SELECT NAME="${layer}__${field}">!;
            $html .= '<OPTION> </OPTION>' unless $value;
            foreach my $record ( qsearch( $def->{select_table}, {} ) ) {
              my $rvalue = $record->getfield($def->{select_key});
              $html .= qq!<OPTION VALUE="$rvalue"!.
                       ( $rvalue==$value ? ' SELECTED>' : '>' ).
                       $record->getfield($def->{select_label}). '</OPTION>';
            }
            $html .= '</SELECT>';
          } elsif ( $def->{type} eq 'radius_usergroup_selector' ) {
            $html .= FS::svc_acct::radius_usergroup_selector(
              [ split(',', $value) ], "${layer}__${field}" );
          } else {
            $html .= '<font color="#ff0000">unknown type'. $def->{type};
          }
        } else {
          $html .=
            qq!<INPUT TYPE="text" NAME="${layer}__${field}" VALUE="$value">!;
        }
        $html .= "</TD></TR>\n";
      }
      $part_svc->svcpart('') if $clone; #undone
      $html .= "</TABLE>";

      $html .= '<BR><INPUT TYPE="submit" VALUE="'.
               ($hashref->{svcpart} ? 'Apply changes' : 'Add service'). '">';

      $html;

    },
  );

%>
Table <%= $widget->html %>
  </BODY>
</HTML>

