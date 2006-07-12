<%
my $part_svc;
my $clone = '';
if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {#clone
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
<%= include("/elements/header.html","$action Service Definition",
           menubar( 'Main Menu'         => $p,
                    'View all service definitions' => "${p}browse/part_svc.cgi"
                  ),
           )
%>

<FORM NAME="dummy">

      Service Part #<%= $part_svc->svcpart ? $part_svc->svcpart : "(NEW)" %>
<BR><BR>
Service  <INPUT TYPE="text" NAME="svc" VALUE="<%= $hashref->{svc} %>"><BR>
Disable new orders <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<%= $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>><BR>
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<%= $hashref->{svcpart} %>">
<BR>
Service definitions are the templates for items you offer to your customers.
<UL><LI>svc_acct - Accounts - anything with a username (Mailboxes, PPP accounts, shell accounts, RADIUS entries for broadband, etc.)
    <LI>svc_domain - Domains
    <LI>svc_forward - mail forwarding
    <LI>svc_www - Virtual domain website
    <LI>svc_broadband - Broadband/High-speed Internet service (always-on)
    <LI>svc_phone - Customer phone numbers
    <LI>svc_external - Externally-tracked service
<!--   <LI>svc_charge - One-time charges (Partially unimplemented)
       <LI>svc_wo - Work orders (Partially unimplemented)
-->
</UL>
For the selected table, you can give fields default or fixed (unchangable)
values, or select an inventory class to manually or automatically fill in
that field.
<BR><BR>

<%

#these might belong somewhere else for other user interfaces 
#pry need to eventually create stuff that's shared amount UIs
my $conf = new FS::Conf;
my %defs = (

  'svc_acct' => {
    'dir'       => 'Home directory',
    'uid'       => 'UID (set to fixed and blank for no UIDs)',
    'slipip'    => 'IP address',
#    'popnum'    => qq!<A HREF="$p/browse/svc_acct_pop.cgi/">POP number</A>!,
    'popnum'    => {
                     desc => 'Access number',
                     type => 'select',
                     select_table => 'svc_acct_pop',
                     select_key   => 'popnum',
                     select_label => 'city',
                   },
    'username'  => {
                     desc => 'Username',
                     type => 'text',
                     disable_default => 1,
                     disable_fixed => 1,
                   },
    'quota'     => { 
                     desc => '',
                     type => 'text',
                     disable_inventory => 1,
                   },
    '_password' => 'Password',
    'gid'       => 'GID (when blank, defaults to UID)',
    'shell'     => {
                     #desc =>'Shell (all service definitions should have a default or fixed shell that is present in the <b>shells</b> configuration file, set to blank for no shell tracking)',
                     desc =>'Shell ( set to blank for no shell tracking)',
                     type =>'select',
                     select_list => [ $conf->config('shells') ],
                     disable_inventory => 1,
                   },
    'finger'    => 'Real name (GECOS)',
    'domsvc'    => {
                     desc =>'svcnum from svc_domain',
                     type =>'select',
                     select_table => 'svc_domain',
                     select_key   => 'svcnum',
                     select_label => 'domain',
                     disable_inventory => 1,
                   },
    'usergroup' => {
                     desc =>'RADIUS groups',
                     type =>'radius_usergroup_selector',
                     disable_inventory => 1,
                   },
    'seconds'   => { desc => '',
                     type => 'text',
                     disable_inventory => 1,
                   },
  },

  'svc_domain' => {
    'domain'    => 'Domain',
  },

  'svc_forward' => {
    'srcsvc'    => 'service from which mail is to be forwarded',
    'dstsvc'    => 'service to which mail is to be forwarded',
    'dst'       => 'someone@another.domain.com to use when dstsvc is 0',
  },

#  'svc_charge' => {
#    'amount'    => 'amount',
#  },
#  'svc_wo' => {
#    'worker'    => 'Worker',
#    '_date'      => 'Date',
#  },

  'svc_www' => {
    #'recnum' => '',
    #'usersvc' => '',
  },

  'svc_broadband' => {
    'speed_down' => 'Maximum download speed for this service in Kbps.  0 denotes unlimited.',
    'speed_up' => 'Maximum upload speed for this service in Kbps.  0 denotes unlimited.',
    'ip_addr' => 'IP address.  Leave blank for automatic assignment.',
    'blocknum' => 'Address block.',
  },

  'svc_phone' => {
    'countrycode' => { desc => 'Country code',
                       type => 'text',
                       disable_inventory => 1,
                     },
    'phonenum'    => 'Phone number',
    'pin'         => { desc => 'Personal Identification Number',
                       type => 'text',
                       disable_inventory => 1,
                     },
  },

  'svc_external' => {
    #'id' => '',
    #'title' => '',
  },

);

  my %vfields;
  foreach my $svcdb (grep dbdef->table($_), keys %defs ) {
    my $self = "FS::$svcdb"->new;
    $vfields{$svcdb} = {};
    foreach my $field ($self->virtual_fields) { # svc_Common::virtual_fields with a null svcpart returns all of them
      my $pvf = $self->pvf($field);
      my @list = $pvf->list;
      if (scalar @list) {
        $defs{$svcdb}->{$field} = { desc        => $pvf->label,
                                    type        => 'select',
                                    select_list => \@list };
      } else {
        $defs{$svcdb}->{$field} = $pvf->label;
      } #endif
      $vfields{$svcdb}->{$field} = $pvf;
      warn "\$vfields{$svcdb}->{$field} = $pvf";
    } #next $field
  } #next $svcdb

  #code duplication w/ edit/part_svc.cgi, should move this hash to part_svc.pm
  # and generalize the subs
  # condition sub is tested to see whether to disable display of this choice
  # params: ( $def, $layer, $field )  (see SUB below)
  my $inv_sub = sub {
    ref($_[0]) && (    $_[0]->{disable_inventory} 
                    || $_[0]->{'type'} ne 'text'  )
  };
  tie my %flag, 'Tie::IxHash',
    ''  => { 'desc' => 'No default', },
    'D' => { 'desc' => 'Default',
             'condition' =>
               sub { ref($_[0]) && $_[0]->{disable_default} }, 
           },
    'F' => { 'desc' => 'Fixed (unchangeable)',
             'condition' =>
               sub { ref($_[0]) && $_[0]->{disable_fixed} }, 
           },
# need to template-ize httemplate/edit/svc_* first
#    'M' => { 'desc' => 'Manual selection from inventory',
#             'condition' => $inv_sub,
#           },
    'A' => { 'desc' => 'Automatically fill in from inventory',
             'condition' => $inv_sub,
           },
    'X' => { 'desc' => 'Excluded',
             'condition' =>
               sub { ! $vfields{$_[1]}->{$_[2]} },

           },
  ;
  
  my @dbs = $hashref->{svcdb}
             ? ( $hashref->{svcdb} )
             : qw( svc_acct svc_domain svc_forward svc_www svc_broadband svc_phone svc_external );

  tie my %svcdb, 'Tie::IxHash', map { $_=>$_ } grep dbdef->table($_), @dbs;
  my $widget = new HTML::Widgets::SelectLayers(
    #'selected_layer' => $p_svcdb,
    'selected_layer' => $hashref->{svcdb} || 'svc_acct',
    'options'        => \%svcdb,
    'form_name'      => 'dummy',
    #'form_action'    => 'process/part_svc.cgi',
    'form_action'    => 'part_svc.cgi', #self
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
               "<TR><TH COLSPAN=$columns>Exports</TH></TR><TR>";
      foreach my $part_export ( @part_export ) {
        $html .= '<TD><INPUT TYPE="checkbox"'.
                 ' NAME="exportnum'. $part_export->exportnum. '"  VALUE="1" ';
        $html .= 'CHECKED'
          if ( $clone || $part_svc->svcpart ) #null svcpart search causing error
              && qsearchs( 'export_svc', {
                                   exportnum => $part_export->exportnum,
                                   svcpart   => $clone || $part_svc->svcpart });
        $html .= '>'. $part_export->exportnum. ': '. $part_export->exporttype.
                 ' to '. $part_export->machine. '</TD>';
        $count++;
        $html .= '</TR><TR>' unless $count % $columns;
      }
      $html .= '</TR></TABLE><BR><BR>';

      $html .= include('/elements/table-grid.html', 'cellpadding' => 4 ).
               '<TR>'.
                 '<TH CLASS="grid" BGCOLOR="#cccccc">Field</TH>'.
                 '<TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=2>Modifier</TH>'.
               '</TR>';

      my $bgcolor1 = '#eeeeee';
      my $bgcolor2 = '#ffffff';
      my $bgcolor;

      #yucky kludge
      my @fields = defined( dbdef->table($layer) )
                      ? grep { $_ ne 'svcnum' } fields($layer)
                      : ();
      push @fields, 'usergroup' if $layer eq 'svc_acct'; #kludge
      $part_svc->svcpart($clone) if $clone; #haha, undone below


      foreach my $field (@fields) {

        my $part_svc_column = $part_svc->part_svc_column($field);
        my $value = $part_svc_column->columnvalue;
        my $flag = $part_svc_column->columnflag;
        my $def = $defs{$layer}{$field};
        my $desc = ref($def) ? $def->{desc} : $def;

        if ( $bgcolor eq $bgcolor1 ) {
          $bgcolor = $bgcolor2;
        } else {
          $bgcolor = $bgcolor1;
        }
        
        $html .= qq!<TR><TD CLASS="grid" BGCOLOR="$bgcolor" ALIGN="right">!.
                 $field;
        $html .= "- <FONT SIZE=-1>$desc</FONT>" if $desc;
        $html .=  "</TD>";
        $flag = '' if ref($def) && $def->{type} eq 'disabled';

        $html .= qq!<TD CLASS="grid" BGCOLOR="$bgcolor">!;

        if ( ref($def) && $def->{type} eq 'disabled' ) {
        
          $html .= 'No default';

        } else {

          $html .= qq!<SELECT NAME="${layer}__${field}_flag"!.
                      qq! onChange="${layer}__${field}_flag_changed(this)">!;

          foreach my $f ( keys %flag ) {

            #here is where the SUB from above is called, to skip some choices
            next if $flag{$f}->{condition}
                 && &{ $flag{$f}->{condition} }( $def, $layer, $field );

            $html .= qq!<OPTION VALUE="$f"!.
                     ' SELECTED'x($flag eq $f ).
                     '>'. $flag{$f}->{desc};

          }

          $html .= '</SELECT>';

          $html .= join("\n",
            '<SCRIPT>',
            "  function ${layer}__${field}_flag_changed(what) {",
            '    var f = what.options[what.selectedIndex].value;',
            '    if ( f == "" || f == "X" ) { //disable',
            "      what.form.${layer}__${field}.disabled = true;".
            "      what.form.${layer}__${field}.style.backgroundColor = '#dddddd';".
            "      if ( what.form.${layer}__${field}_classnum ) {".
            "        what.form.${layer}__${field}_classnum.disabled = true;".
            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#dddddd';".
            "      }".
            '    } else if ( f == "D" || f == "F" ) { //enable, text box',
            "      what.form.${layer}__${field}.disabled = false;".
            "      what.form.${layer}__${field}.style.backgroundColor = '#ffffff';".
            "      what.form.${layer}__${field}.style.display = '';".
            "      if ( what.form.${layer}__${field}_classnum ) {".
            "        what.form.${layer}__${field}_classnum.disabled = false;".
            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#ffffff';".
            "        what.form.${layer}__${field}_classnum.style.display = 'none';".
            "      }".
            '    } else if ( f == "M" || f == "A" ) { //enable, inventory',
            "      what.form.${layer}__${field}.disabled = false;".
            "      what.form.${layer}__${field}.style.backgroundColor = '#ffffff';".
            "      what.form.${layer}__${field}.style.display = 'none';".
            "      if ( what.form.${layer}__${field}_classnum ) {".
            "        what.form.${layer}__${field}_classnum.disabled = false;".
            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#ffffff';".
            "        what.form.${layer}__${field}_classnum.style.display = '';".
            "      }".
            '    }',
            '  }',
            '</SCRIPT>',
          );

        }

        $html .= qq!</TD><TD CLASS="grid" BGCOLOR="$bgcolor">!;

        my $disabled = $flag ? ''
                             : 'DISABLED STYLE="background-color: #dddddd"';

        if ( ! ref($def) || $def->{type} eq 'text' ) {

          my $nodisplay = ' STYLE="display:none"';
          my $is_inv = ( $flag =~ /^[MA]$/ );

          $html .=
            qq!<INPUT TYPE="text" NAME="${layer}__${field}" VALUE="$value" !.
            $disabled.
            ( $is_inv ? $nodisplay : $disabled ).
            '>';

          $html .= include('/elements/select-table.html',
                             'element_name' => "${layer}__${field}_classnum",
                             'element_etc'  => ( $is_inv
                                                   ? $disabled
                                                   : $nodisplay
                                               ),
                             'table'        => 'inventory_class',
                             'name_col'     => 'classname',
                             'value'        => $value,
                             'empty_label'  => 'Select inventory class',
                          );

        } elsif ( $def->{type} eq 'select' ) {

          $html .= qq!<SELECT NAME="${layer}__${field}" $disabled>!;
          $html .= '<OPTION> </OPTION>' unless $value;
          if ( $def->{select_table} ) {
            foreach my $record ( qsearch( $def->{select_table}, {} ) ) {
              my $rvalue = $record->getfield($def->{select_key});
              $html .= qq!<OPTION VALUE="$rvalue"!.
                       ( $rvalue==$value ? ' SELECTED>' : '>' ).
                       $record->getfield($def->{select_label}). '</OPTION>';
            } #next $record
          } else { # select_list
            foreach my $item ( @{$def->{select_list}} ) {
              $html .= qq!<OPTION VALUE="$item"!.
                       ( $item eq $value ? ' SELECTED>' : '>' ).
                       $item. '</OPTION>';
            } #next $item
          } #endif
          $html .= '</SELECT>';

        } elsif ( $def->{type} eq 'radius_usergroup_selector' ) {

          #XXX disable the RADIUS usergroup selector?  ugh it sure does need
          #an overhaul, people have dum group problems because of it

          $html .= FS::svc_acct::radius_usergroup_selector(
            [ split(',', $value) ], "${layer}__${field}" );

        } elsif ( $def->{type} eq 'disabled' ) {

          $html .=
            qq!<INPUT TYPE="hidden" NAME="${layer}__${field}" VALUE="">!;

        } else {

          $html .= '<font color="#ff0000">unknown type'. $def->{type};

        }

        $html .= "</TD></TR>\n";

      } #foreach my $field (@fields) {

      $part_svc->svcpart('') if $clone; #undone
      $html .= "</TABLE>";

      $html .= include('/elements/progress-init.html',
                         $layer, #form name
                         [ qw(svc svcpart disabled exportnum), @fields ],
                         'process/part_svc.cgi',
                         $p.'browse/part_svc.cgi',
                         $layer,
                      );
      $html .= '<BR><INPUT NAME="submit" TYPE="button" VALUE="'.
               ($hashref->{svcpart} ? 'Apply changes' : 'Add service'). '" '.
               ' onClick="document.'. "$layer.submit.disabled=true; ".
               "fixup(document.$layer); $layer". 'process();">';

      #$html .= '<BR><INPUT TYPE="submit" VALUE="'.
      #         ($hashref->{svcpart} ? 'Apply changes' : 'Add service'). '">';

      $html;

    },
  );

%>
Table <%= $widget->html %>
  </BODY>
</HTML>

