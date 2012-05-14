<& /elements/header.html, "$action Service Definition",
           menubar('View all service definitions' => "${p}browse/part_svc.cgi"),
           #" onLoad=\"visualize()\""
&>

<& /elements/init_overlib.html &>

<BR>

<FORM NAME="dummy">

<FONT CLASS="fsinnerbox-title">Service Part #<% $part_svc->svcpart ? $part_svc->svcpart : "(NEW)" %></FONT>
<TABLE CLASS="fsinnerbox">
<TR>
  <TD ALIGN="right">Service</TD>
  <TD><INPUT TYPE="text" NAME="svc" VALUE="<% $hashref->{svc} %>"></TD>
<TR>

<& /elements/tr-select-part_svc_class.html, curr_value=>$hashref->{classnum} &>

<TR>
  <TD ALIGN="right">Self-service access</TD>
  <TD>
    <SELECT NAME="selfservice_access">
% tie my %selfservice_access, 'Tie::IxHash', #false laziness w/browse/part_svc
%   ''         => 'Yes',
%   'hidden'   => 'Hidden',
%   'readonly' => 'Read-only',
% ;
% for (keys %selfservice_access) {
  <OPTION VALUE="<% $_ %>"
          <% $_ eq $hashref->{'selfservice_access'} ? 'SELECTED' : '' %>
  ><% $selfservice_access{$_} %>
% }
    </SELECT>
  </TD>
</TR>


<TR>
  <TD ALIGN="right">Disable new orders</TD>
  <TD><INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>></TD>
</TR>

<TR>
  <TD ALIGN="right">Preserve this service on package cancellation</TD>
  <TD><INPUT TYPE="checkbox" NAME="preserve" VALUE="Y"<% $hashref->{'preserve'} eq 'Y' ? ' CHECKED' : '' %>>&nbsp;</TD>
</TR>

</TABLE>

<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $hashref->{svcpart} %>">

<BR>

% my %vfields;
%  #code duplication w/ edit/part_svc.cgi, should move this hash to part_svc.pm
%  # and generalize the subs
%  # condition sub is tested to see whether to disable display of this choice
%  # params: ( $def, $layer, $field )  (see SUB below)
%  my $inv_sub = sub {
%                      $_[0]->{disable_inventory}
%                        || $_[0]->{'type'} ne 'text'
%                    };
%  tie my %flag, 'Tie::IxHash',
%    ''  => { 'desc' => 'No default', },
%    'D' => { 'desc' => 'Default',
%             'condition' =>
%               sub { $_[0]->{disable_default} }, 
%           },
%    'F' => { 'desc' => 'Fixed (unchangeable)',
%             'condition' =>
%               sub { $_[0]->{disable_fixed} }, 
%           },
%    'S' => { 'desc' => 'Selectable Choice',
%             'condition' =>
%               sub { !ref($_[0]) || $_[0]->{disable_select} }, 
%           },
%    'M' => { 'desc' => 'Manual selection from inventory',
%             'condition' => $inv_sub,
%           },
%    'A' => { 'desc' => 'Automatically fill in from inventory',
%             'condition' => $inv_sub,
%           },
%    'H' => { 'desc' => 'Select from hardware class',
%             'condition' => sub { $_[0]->{type} ne 'select-hardware' },
%           },
%    'X' => { 'desc' => 'Excluded',
%             'condition' =>
%               sub { ! $vfields{$_[1]}->{$_[2]} },
%
%           },
%  ;
%  
%  my @dbs = $hashref->{svcdb}
%             ? ( $hashref->{svcdb} )
%             : FS::part_svc->svc_tables();
%
%  my $help = '';
%  unless ( $hashref->{svcpart} ) {
%    $help = '&nbsp;'.
%            include('/elements/popup_link.html',
%                      'action' => $p.'docs/part_svc-table.html',
%                      'label'  => 'help',
%                      'actionlabel' => 'Service table help',
%                      'width'       => 763,
%                      #'height'      => 400,
%                    );
%  }
%
%  tie my %svcdb, 'Tie::IxHash', map { $_=>$_ } grep dbdef->table($_), @dbs;
%  my $widget = new HTML::Widgets::SelectLayers(
%    #'selected_layer' => $p_svcdb,
%    'selected_layer' => $hashref->{svcdb} || 'svc_acct',
%    'options'        => \%svcdb,
%    'form_name'      => 'dummy',
%    #'form_action'    => 'process/part_svc.cgi',
%    'form_action'    => 'part_svc.cgi', #self
%    'form_elements'  => [qw( svc svcpart classnum selfservice_access
%                             disabled preserve
%                        )],
%    'html_between'   => $help,
%    'layer_callback' => sub {
%      my $layer = shift;
%      
%      my $html = qq!<INPUT TYPE="hidden" NAME="svcdb" VALUE="$layer">!;
%
%      #$html .= $svcdb_info;
%
%      my $columns = 3;
%      my $count = 0;
%      my $communigate = 0;
%      my @part_export =
%        map { qsearch( 'part_export', {exporttype => $_ } ) }
%          keys %{FS::part_export::export_info($layer)};
%      $html .= '<BR><BR>'. include('/elements/table.html') . 
%               "<TR><TH COLSPAN=$columns>Exports</TH></TR><TR>";
%      foreach my $part_export ( @part_export ) {
%        $communigate++ if $part_export->exporttype =~ /^communigate/;
%        $html .= '<TD><INPUT TYPE="checkbox"'.
%                 ' NAME="exportnum'. $part_export->exportnum. '"  VALUE="1" ';
%        $html .= 'CHECKED'
%          if ( $clone || $part_svc->svcpart ) #null svcpart search causing error
%              && qsearchs( 'export_svc', {
%                                   exportnum => $part_export->exportnum,
%                                   svcpart   => $clone || $part_svc->svcpart });
%        $html .= '>'.$part_export->exportnum. ': ';
%        $html .= $part_export->exportname . '<DIV ALIGN="right"><FONT SIZE=-1>'
%          if ( $part_export->exportname );
%        $html .= $part_export->exporttype. ' to '. $part_export->machine;
%        $html .= '</FONT></DIV>' if ( $part_export->exportname );
%        $html .= '</TD>';
%        $count++;
%        $html .= '</TR><TR>' unless $count % $columns;
%      }
%      $html .= '</TR></TABLE><BR><BR>'. $mod_info;
%
%      $html .= include('/elements/table-grid.html', 'cellpadding' => 4 ).
%               '<TR>'.
%                 '<TH CLASS="grid" BGCOLOR="#cccccc">Field</TH>'.
%                 '<TH CLASS="grid" BGCOLOR="#cccccc">Label</TH>'.
%                 '<TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=2>Modifier</TH>'.
%               '</TR>';
%
%      my $bgcolor1 = '#eeeeee';
%      my $bgcolor2 = '#ffffff';
%      my $bgcolor;
%
%      #yucky kludge
%      my @fields = ();
%      if ( defined( dbdef->table($layer) ) ) {
%        @fields = grep {
%            $_ ne 'svcnum'
%            && ( $communigate || !$communigate_fields{$layer}->{$_} )
%            && ( !FS::part_svc->svc_table_fields($layer)
%                   ->{$_}->{disable_part_svc_column}
%                 || $part_svc->part_svc_column($_)->columnflag
%               )
%        } fields($layer);
%      }
%      push @fields, 'usergroup' 
%        if $layer eq 'svc_acct'
%          or ( $layer eq 'svc_broadband' and 
%               $conf->exists('svc_broadband-radius') ); # double kludge
%               # (but we do want to check the config, right?)
%      $part_svc->svcpart($clone) if $clone; #haha, undone below
%
%
%      foreach my $field (@fields) {
%
%        #a few lines of false laziness w/browse/part_svc.cgi
%        my $def = FS::part_svc->svc_table_fields($layer)->{$field};
%        my $def_info  = $def->{'def_info'};
%        my $formatter = $def->{'format'} || sub { shift };
%
%        my $part_svc_column = $part_svc->part_svc_column($field);
%        my $label = $part_svc_column->columnlabel || $def->{'label'};
%        my $value = &$formatter($part_svc_column->columnvalue);
%        my $flag  = $part_svc_column->columnflag;
%
%        if ( $bgcolor eq $bgcolor1 ) {
%          $bgcolor = $bgcolor2;
%        } else {
%          $bgcolor = $bgcolor1;
%        }
%        
%        $html .= qq!<TR><TD ROWSPAN=2 CLASS="grid" BGCOLOR="$bgcolor" ALIGN="right">!.
%                 ( $def->{'label'} || $field ).
%                 "</TD>";
%
%        $html .= qq!<TD ROWSPAN=2 CLASS="grid" BGCOLOR="$bgcolor"><INPUT NAME="${layer}__${field}_label" VALUE="!. encode_entities($label). '" STYLE="text-align:right"></TD>';
%
%        $flag = '' if $def->{type} eq 'disabled';
%
%        $html .= qq!<TD CLASS="grid" BGCOLOR="$bgcolor">!;
%
%        if ( $def->{type} eq 'disabled' ) {
%        
%          $html .= 'No default';
%
%        } else {
%
%          $html .= qq!<SELECT NAME="${layer}__${field}_flag"!.
%                      qq! onChange="${layer}__${field}_flag_changed(this)">!;
%
%          foreach my $f ( keys %flag ) {
%
%            # need to template-ize more httemplate/edit/svc_* first
%            next if $f eq 'M' and $layer !~ /^svc_(broadband|external|phone|dish)$/;
%
%            #here is where the SUB from above is called, to skip some choices
%            next if $flag{$f}->{condition}
%                 && &{ $flag{$f}->{condition} }( $def, $layer, $field );
%
%            $html .= qq!<OPTION VALUE="$f"!.
%                     ' SELECTED'x($flag eq $f ).
%                     '>'. $flag{$f}->{desc};
%
%          }
%
%          $html .= '</SELECT>';
%
%          $html .= join("\n",
%            '<SCRIPT>',
%            "  function ${layer}__${field}_flag_changed(what) {",
%            '    var f = what.options[what.selectedIndex].value;',
%            '    if ( f == "" || f == "X" ) { //disable',
%            "      what.form.${layer}__${field}.disabled = true;".
%            "      what.form.${layer}__${field}.style.backgroundColor = '#dddddd';".
%            "      if ( what.form.${layer}__${field}_classnum ) {".
%            "        what.form.${layer}__${field}_classnum.disabled = true;".
%            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#dddddd';".
%            "      }".
%            '    } else if ( f == "D" || f == "F" || f =="S" ) { //enable, text box',
%            "      what.form.${layer}__${field}.disabled = false;".
%            "      what.form.${layer}__${field}.style.backgroundColor = '#ffffff';".
%            "      if ( f == 'S' || '${field}' == 'usergroup' ) {". # kludge
%            "        what.form.${layer}__${field}.multiple = true;".
%            "      } else {".
%            "        what.form.${layer}__${field}.multiple = false;".
%            "      }".
%            "      what.form.${layer}__${field}.style.display = '';".
%            "      if ( what.form.${layer}__${field}_classnum ) {".
%            "        what.form.${layer}__${field}_classnum.disabled = false;".
%            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#ffffff';".
%            "        what.form.${layer}__${field}_classnum.style.display = 'none';".
%            "      }".
%            '    } else if ( f == "M" || f == "A" || f == "H" ) { '.
%                   '//enable, inventory',
%            "      what.form.${layer}__${field}.disabled = false;".
%            "      what.form.${layer}__${field}.style.backgroundColor = '#ffffff';".
%            "      what.form.${layer}__${field}.style.display = 'none';".
%            "      if ( what.form.${layer}__${field}_classnum ) {".
%            "        what.form.${layer}__${field}_classnum.disabled = false;".
%            "        what.form.${layer}__${field}_classnum.style.backgroundColor = '#ffffff';".
%            "        what.form.${layer}__${field}_classnum.style.display = '';".
%            "      }".
%            '    }',
%            '  }',
%            '</SCRIPT>',
%          );
%
%        }
%
%        $html .= qq!</TD><TD CLASS="grid" BGCOLOR="$bgcolor">!;
%
%        my $disabled = $flag ? ''
%                             : 'DISABLED STYLE="background-color: #dddddd"';
%        my $nodisplay = ' STYLE="display:none"';
%
%        if ( !$def->{type} || $def->{type} eq 'text' ) {
%
%          my $is_inv = ( $flag =~ /^[MA]$/ );
%
%          $html .=
%            qq!<INPUT TYPE="text" NAME="${layer}__${field}" VALUE="$value" !.
%            $disabled.
%            ( $is_inv ? $nodisplay : $disabled ).
%            '>';
%
%          $html .= include('/elements/select-table.html',
%                             'element_name' => "${layer}__${field}_classnum",
%                             'id'           => "${layer}__${field}_classnum",
%                             'element_etc'  => ( $is_inv
%                                                   ? $disabled
%                                                   : $nodisplay
%                                               ),
%                             'table'        => 'inventory_class',
%                             'name_col'     => 'classname',
%                             'value'        => $value,
%                             'empty_label'  => 'Select inventory class',
%                          );
%
%        } elsif ( $def->{type} eq 'checkbox' ) {
%
%          $html .= include('/elements/checkbox.html',
%                             'field'      => $layer.'__'.$field,
%                             'curr_value' => $value,
%                             'value'      => 'Y',
%                          );
%
%        } elsif ( $def->{type} eq 'select' ) {
%
%          $html .= qq!<SELECT NAME="${layer}__${field}" $disabled!;
%          $html .= ' MULTIPLE' if $flag eq 'S';
%          $html .= '>';
%          $html .= '<OPTION> </OPTION>' unless $value;
%          if ( $def->{select_table} ) {
%            foreach my $record ( qsearch( $def->{select_table}, {} ) ) {
%              my $rvalue = $record->getfield($def->{select_key});
%              my $select_label = $def->{select_label};
%              $html .= qq!<OPTION VALUE="$rvalue"!.
%                  (grep(/^$rvalue$/, split(',',$value)) ? ' SELECTED>' : '>' ).
%                  $record->$select_label(). '</OPTION>';
%            } #next $record
%          } elsif ( $def->{select_list} ) {
%            foreach my $item ( @{$def->{select_list}} ) {
%              $html .= qq!<OPTION VALUE="$item"!.
%                    (grep(/^$item$/, split(',',$value)) ? ' SELECTED>' : '>' ).
%                    $item. '</OPTION>';
%            } #next $item
%          } elsif ( $def->{select_hash} ) {
%            if ( ref($def->{select_hash}) eq 'ARRAY' ) {
%              tie my %hash, 'Tie::IxHash', @{ $def->{select_hash} };
%              $def->{select_hash} = \%hash;
%            }
%            foreach my $key ( keys %{$def->{select_hash}} ) {
%              $html .= qq!<OPTION VALUE="$key"!.
%                    (grep(/^$key$/, split(',',$value)) ? ' SELECTED>' : '>' ).
%                    $def->{select_hash}{$key}. '</OPTION>';
%            } #next $key
%          } #endif
%          $html .= '</SELECT>';
%
%        } elsif ( $def->{type} eq 'textarea' ) {
%
%          $html .=
%            qq!<TEXTAREA NAME="${layer}__${field}">!. encode_entities($value).
%            '</TEXTAREA>';
%
%        } elsif ( $def->{type} =~ /select-(.*?).html/ ) {
%
%          $html .= include("/elements/".$def->{type},
%                             'curr_value'   => $value,
%                             'element_name' => "${layer}__${field}",
%                             'element_etc'  => $disabled,
%                             'multiple'     => ($def->{multiple} ||
%                                                $flag eq 'S'),
%                                 # allow the table def to force 'multiple'
%                          );
%
%        } elsif ( $def->{type} eq 'communigate_pro-accessmodes' ) {
%
%          $html .= include('/elements/communigate_pro-accessmodes.html',
%                             'element_name_prefix' => "${layer}__${field}_",
%                             'curr_value'          => $value,
%                             #doesn't work#'element_etc'  => $disabled,
%                          );
%
%        } elsif ( $def->{type} eq 'select-hardware' ) {
%
%          $html .= qq!<INPUT TYPE="text" NAME="${layer}__${field}" $disabled>!;
%          $html .= include('/elements/select-hardware_class.html',
%                             'curr_value'    => $value,
%                             'element_name'  => "${layer}__${field}_classnum",
%                             'id'            => "${layer}__${field}_classnum",
%                             'element_etc'   => $flag ne 'H' && $nodisplay,
%                             'empty_label'   => 'Select hardware class',
%                          );
%
%        } elsif ( $def->{type} eq 'disabled' ) {
%
%          $html .=
%            qq!<INPUT TYPE="hidden" NAME="${layer}__${field}" VALUE="">!;
%
%        } else {
%
%          $html .= '<font color="#ff0000">unknown type '. $def->{type};
%
%        }
%
%        $html .= "</TD></TR>\n";

%        $def_info = "($def_info)" if $def_info;
%        $html .=
%          qq!<TR>!.
%          qq!  <TD COLSPAN=2 BGCOLOR="$bgcolor" ALIGN="center" !.
%          qq!      STYLE="padding:0; border-top: none">!.
%          qq!    <FONT SIZE="-1"><I>$def_info</I></FONT>!.
%          qq!  </TD>!.
%          qq!</TR>\n!;
%
%      } #foreach my $field (@fields) {
%
%      $part_svc->svcpart('') if $clone; #undone
%      $html .= "</TABLE>";
%
%      $html .= include('/elements/progress-init.html',
%                         $layer, #form name
%                         [ qw(svc svcpart classnum selfservice_access
%                              disabled preserve
%                              exportnum),
%                           @fields ],
%                         'process/part_svc.cgi',
%                         $p.'browse/part_svc.cgi',
%                         $layer,
%                      );
%      $html .= '<BR><INPUT NAME="submit" TYPE="button" VALUE="'.
%               ($hashref->{svcpart} ? 'Apply changes' : 'Add service'). '" '.
%               ' onClick="document.'. "$layer.submit.disabled=true; ".
%               "fixup(document.$layer); $layer". 'process();">';
%
%      #$html .= '<BR><INPUT TYPE="submit" VALUE="'.
%      #         ($hashref->{svcpart} ? 'Apply changes' : 'Add service'). '">';
%
%      $html;
%
%    },
%  );

<BR>
Table <% $widget->html %>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = FS::Conf->new;
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

my %communigate_fields = (
  'svc_acct'        => { map { $_=>1 }
                           qw( file_quota file_maxnum file_maxsize
                               password_selfchange password_recover
                             ),
                           grep /^cgp_/, fields('svc_acct')
                       },
  'svc_domain'      => { map { $_=>1 }
                           qw( max_accounts trailer parent_svcnum ),
                           grep /^(cgp|acct_def)_/, fields('svc_domain')
                       },
  #'svc_forward'     => { map { $_=>1 } qw( ) },
  #'svc_mailinglist' => { map { $_=>1 } qw( ) },
  #'svc_cert'        => { map { $_=>1 } qw( ) },
);

my $mod_info = '
For the selected table, you can give fields default or fixed (unchangable)
values, or select an inventory class to manually or automatically fill in
that field.
';

</%init>



