<% include('/elements/header.html', "$action Export", '', ' onLoad="visualize()"') %>

<% include('/elements/error.html') %>

<FORM NAME="dummy">
<INPUT TYPE="hidden" NAME="exportnum" VALUE="<% $part_export->exportnum %>">

<% ntable("#cccccc",2) %>
<TR>
  <TD ALIGN="right">Export name</TD>
  <TD>
    <INPUT TYPE="text" NAME="exportname" VALUE="<% $part_export->exportname %>">
  </TD>
</TR>
<TR>
  <TD ALIGN="right">Export host</TD>
  <TD>
    <INPUT TYPE="text" NAME="machine" VALUE="<% $part_export->machine %>">
  </TD>
</TR>
<TR>
  <TD ALIGN="right">Export</TD>
  <TD><% $widget->html %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
#  $cgi->param('clone', $1);
#} else {
#  $cgi->param('clone', '');
#}

my($query) = $cgi->keywords;
my $action = '';
my $part_export = '';
if ( $cgi->param('error') ) {
  $part_export = new FS::part_export ( {
    map { $_, scalar($cgi->param($_)) } fields('part_export')
  } );
} elsif ( $query =~ /^(\d+)$/ ) {
  $part_export = qsearchs('part_export', { 'exportnum' => $1 } );
} else {
  $part_export = new FS::part_export;
}
$action ||= $part_export->exportnum ? 'Edit' : 'Add';

#my $exports = FS::part_export::export_info($svcdb);
my $exports = FS::part_export::export_info();

tie my %layers, 'Tie::IxHash',
  '' => '',
  map { $_ => "$_ - ". $exports->{$_}{desc} } 
  sort { $a cmp $b }
  keys %$exports;
;

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => $part_export->exporttype,
  'options'        => \%layers,
  'form_name'      => 'dummy',
  'form_action'    => 'process/part_export.cgi',
  'form_text'      => [qw( exportnum exportname machine )],
#  'form_checkbox'  => [qw()],
  'html_between'    => "</TD></TR></TABLE>\n",
  'layer_callback'  => sub {
    my $layer = shift;
    my $html = qq!<INPUT TYPE="hidden" NAME="exporttype" VALUE="$layer">!.
               ntable("#cccccc",2);

    $html .= '<TR><TD ALIGN="right">Description</TD><TD BGCOLOR=#ffffff>'.
             $exports->{$layer}{notes}. '</TD></TR>'
      if $layer;

    foreach my $option ( keys %{$exports->{$layer}{options}} ) {
      my $optinfo = $exports->{$layer}{options}{$option};
      die "Retreived non-ref export info option from $layer export: $optinfo"
        unless ref($optinfo);
      my $label = $optinfo->{label};
      my $type = defined($optinfo->{type}) ? $optinfo->{type} : 'text';
      my $value = $cgi->param($option)
                 || ( $part_export->exportnum && $part_export->option($option) )
                 || ( (exists $optinfo->{default} && !$part_export->exportnum)
                      ? $optinfo->{default}
                      : ''
                    );
      if ( $type eq 'title' ) {
        $html .= qq!<TR><TH COLSPAN=1 ALIGN="right"><FONT SIZE="+1">! .
                 $label .
                 '</FONT></TH></TR>';
        next;
      }

      # 'freeform': disables table formatting of options.  Instead, each 
      # option can define "before" and "after" strings which are inserted 
      # around the selector.
      my $freeform = $optinfo->{freeform};
      if ( $freeform ) {
        $html .= $optinfo->{before} || '';
      }
      else {
        $html .= qq!<TR><TD ALIGN="right">$label</TD><TD>!;
      }
      if ( $type eq 'select' ) {
        my $size = defined($optinfo->{size}) ? " SIZE=" . $optinfo->{size} : '';
        my $multi = ($optinfo->{multi} || $optinfo->{multiple})
                      ? ' MULTIPLE' : '';
        $html .= qq!<SELECT NAME="$option"$multi$size>!;
        my @values = split '\s+', $value if $multi;
        my @options;
        if (defined($optinfo->{option_values})) {
          my $valsub = $optinfo->{option_values};
          @options = &$valsub();
        } elsif (defined($optinfo->{options})) {
          @options = @{$optinfo->{options}};
        }
        foreach my $select_option ( @options ) {
          #if ( ref($select_option) ) {
          #} else {
            my $selected = ($multi ? grep {$_ eq $select_option} @values : $select_option eq $value ) ? ' SELECTED' : '';
            my $label = $select_option;
            if (defined($optinfo->{option_label})) {
              my $labelsub = $optinfo->{option_label};
              $label = &$labelsub($select_option);
            }
            $html .= qq!<OPTION VALUE="$select_option"$selected>!.
                     qq!$label</OPTION>!;
          #}
        }
        $html .= '</SELECT>';
      } elsif ( $type eq 'textarea' ) {
        $html .= qq!<TEXTAREA NAME="$option" COLS=80 ROWS=8 WRAP="virtual">!.
                 encode_entities($value). '</TEXTAREA>';
      } elsif ( $type eq 'text' ) {
        $html .= qq!<INPUT TYPE="text" NAME="$option" VALUE="!. #"
                 encode_entities($value). '" SIZE=64>';
      } elsif ( $type eq 'checkbox' ) {
        $html .= qq!<INPUT TYPE="checkbox" NAME="$option" VALUE="1"!;
        $html .= ' CHECKED' if $value;
        $html .= '>';
      } else {
        $html .= "unknown type $type";
      }
      if ( $freeform ) {
        $html .= $optinfo->{after} || '';
      }
      else {
        $html .= '</TD></TR>';
      }
    }

    if ( $exports->{$layer}{nas} and qsearch('nas',{}) ) {
      # show NAS checkboxes
      $html .= '<TR><TD ALIGN="right">Export RADIUS clients</TD><TD>';

      $html .= include('/elements/checkboxes-table.html',
                        'source_obj'    => $part_export,
                        'link_table'    => 'export_nas',
                        'target_table'  => 'nas',
                        #hashref => {},
                        'name_callback' => sub { 
                          $_[0]->shortname . ' (' . $_[0]->nasname . ')',
                        },
                        'default'       => 'yes',
                        'target_link'   => $p.'edit/nas.html?',
                      );

      $html .= '</TD></TR>';
    }

    $html .= '</TABLE>';

    $html .= '<INPUT TYPE="hidden" NAME="options" VALUE="'.
             join(',', keys %{$exports->{$layer}{options}} ). '">';

    $html .= '<INPUT TYPE="hidden" NAME="nodomain" VALUE="'.
             $exports->{$layer}{nodomain}. '">';

    $html .= '<INPUT TYPE="submit" VALUE="'.
             ( $part_export->exportnum ? "Apply changes" : "Add export" ).
             '">';

    $html;
  },
);

</%init>
