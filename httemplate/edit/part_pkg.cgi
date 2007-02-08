%
%
%if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
%  $cgi->param('clone', $1);
%} else {
%  $cgi->param('clone', '');
%}
%if ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
%  $cgi->param('pkgnum', $1);
%} else {
%  $cgi->param('pkgnum', '');
%}
%
%my ($query) = $cgi->keywords;
%
%my $part_pkg = '';
%my @agent_type = ();
%if ( $cgi->param('error') ) {
%  $part_pkg = new FS::part_pkg ( {
%    map { $_, scalar($cgi->param($_)) } fields('part_pkg')
%  } );
%  (@agent_type) = $cgi->param('agent_type');
%}
%
%my $action = '';
%my $clone_part_pkg = '';
%my $pkgpart = '';
%if ( $cgi->param('clone') ) {
%  $pkgpart = $cgi->param('clone');
%  $action = 'Custom Pricing';
%  $clone_part_pkg= qsearchs('part_pkg', { 'pkgpart' => $cgi->param('clone') } );
%  $part_pkg ||= $clone_part_pkg->clone;
%  $part_pkg->disabled('Y'); #isn't sticky on errors
%} elsif ( $query && $query =~ /^(\d+)$/ ) {
%  (@agent_type) = map {$_->typenum} qsearch('type_pkgs',{'pkgpart'=>$1})
%    unless $part_pkg;
%  $part_pkg ||= qsearchs('part_pkg',{'pkgpart'=>$1});
%  $pkgpart = $part_pkg->pkgpart;
%} else {
%  unless ( $part_pkg ) {
%    $part_pkg = new FS::part_pkg {};
%    $part_pkg->plan('flat');
%  }
%}
%unless ( $part_pkg->plan ) { #backwards-compat
%  $part_pkg->plan('flat');
%  $part_pkg->plandata("setup_fee=". $part_pkg->setup. "\n".
%                      "recur_fee=". $part_pkg->recur. "\n");
%}
%$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
%my $hashref = $part_pkg->hashref;
%
%


<% include("/elements/header.html","$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
)) %>
% #), ' onLoad="visualize()"'); 
% if ( $cgi->param('error') ) { 

  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
% } 


<FORM NAME="dummy">

<% itable('',8,1) %><TR><TD VALIGN="top">

Package information

<% ntable("#cccccc",2) %>
  <TR>
    <TD ALIGN="right">Package Definition #</TD>
    <TD BGCOLOR="#ffffff">
      <% $hashref->{pkgpart} ? $hashref->{pkgpart} : "(NEW)" %>
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Package (customer-visible)</TD>
    <TD>
      <INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="<% $part_pkg->pkg %>">
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Comment (customer-hidden)</TD>
    <TD>
      <INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="<%$part_pkg->comment%>">
    </TD>
  </TR>
  <% include( '/elements/tr-select-pkg_class.html', $part_pkg->classnum ) %>
  <TR>
    <TD ALIGN="right">Promotional code</TD>
    <TD>
      <INPUT TYPE="text" NAME="promo_code" SIZE=32 VALUE="<%$part_pkg->promo_code%>">
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Disable new orders</TD>
    <TD>
      <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>
    </TD>
  </TR>

</TABLE>

</TD><TD VALIGN="top">

Tax information
<% ntable("#cccccc", 2) %>
  <TR>
    <TD ALIGN="right">Setup fee tax exempt</TD>
    <TD>
      <INPUT TYPE="checkbox" NAME="setuptax" VALUE="Y" <% $hashref->{setuptax} eq 'Y' ? ' CHECKED' : '' %>>
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Recurring fee tax exempt</TD>
    <TD>
      <INPUT TYPE="checkbox" NAME="recurtax" VALUE="Y" <% $hashref->{recurtax} eq 'Y' ? ' CHECKED' : '' %>>
    </TD>
  </TR>

% my $conf = new FS::Conf; 
% if ( $conf->exists('enable_taxclasses') ) { 

  <TR>
    <TD align="right">Tax class</TD>
    <TD>
      <% include('/elements/select-taxclass.html', $hashref->{taxclass} ) %>
    </TD>
  </TR>

% } else { 

  <% include('/elements/select-taxclass.html', $hashref->{taxclass} ) %>

% } 

</TABLE>
<BR>

Line-item revenue recognition
<% ntable("#cccccc", 2) %>
% tie my %weight, 'Tie::IxHash',
%   'pay_weight'    => 'Payment',
%   'credit_weight' => 'Credit'
% ;
% foreach my $weight (keys %weight) {
    <TR>
      <TD ALIGN="right"><% $weight{$weight} %> weight</TD>
      <TD>
        <INPUT TYPE="text" NAME="<% $weight %>" SIZE=6 VALUE=<% $hashref->{$weight} || 0 %>>
      </TD>
    </TR>
% }
</TABLE>

</TD><TD VALIGN="top">

%#Reseller information      # after 1.7.2
%#<% ntable("#cccccc", 2) %>
%#  <TR>
%#    <TD ALIGN="right"><% 'Agent Types' %></TD>
%#    <TD>
%#      <% include( '/elements/select-table.html',
%#                  'element_name' => 'agent_type',
%#                  'table'        => 'agent_type',
%#  		  'name_col'     => 'atype',
%#  		  'value'        => \@agent_type,
%#  		  'empty_label'  => '(none)',
%#  		  'element_etc'  => 'multiple size="10"',
%#                )
%#      %>
%#    </TD>
%#  </TR>
%#</TABLE>
</TD></TR></TABLE>
%
%
%my $thead =  "\n\n". ntable('#cccccc', 2).
%             '<TR><TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Quan.</FONT></TH>';
%$thead .=  '<TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Primary</FONT></TH>'
%  if dbdef->table('pkg_svc')->column('primary_svc');
%$thead .= '<TH BGCOLOR="#dcdcdc">Service</TH></TR>';
%
%


<BR><BR>Services included
<% itable('', 4, 1) %><TR><TD VALIGN="top">
<% $thead %>
%
%
%my $where =  "WHERE disabled IS NULL OR disabled = ''";
%if ( $pkgpart ) {
%  $where .=  "   OR 0 < ( SELECT quantity FROM pkg_svc
%                           WHERE pkg_svc.svcpart = part_svc.svcpart
%                             AND pkgpart = $pkgpart
%                        )";
%}
%my @part_svc = qsearch('part_svc', {}, '', $where);
%my $q_part_pkg = $clone_part_pkg || $part_pkg;
%my %pkg_svc = map { $_->svcpart => $_ } $q_part_pkg->pkg_svc;
%
%my @fixups = ();
%my $count = 0;
%my $columns = 3;
%foreach my $part_svc ( @part_svc ) {
%  my $svcpart = $part_svc->svcpart;
%  my $pkg_svc = $pkg_svc{$svcpart}
%             || new FS::pkg_svc ( {
%                                   'pkgpart'     => $pkgpart,
%                                   'svcpart'     => $svcpart,
%                                   'quantity'    => 0,
%                                   'primary_svc' => '',
%                                } );
%
%  push @fixups, "pkg_svc$svcpart";
%
%


  <TR>
    <TD>
      <INPUT TYPE="text" NAME="pkg_svc<% $svcpart %>" SIZE=4 MAXLENGTH=3 VALUE="<% $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0 %>">
    </TD>
   
    <TD>
      <INPUT TYPE="radio" NAME="pkg_svc_primary" VALUE="<% $svcpart %>" <% $pkg_svc->primary_svc =~ /^Y/i ? ' CHECKED' : '' %>>
    </TD>

    <TD>
      <A HREF="part_svc.cgi?<% $part_svc->svcpart %>"><% $part_svc->svc %></A>      <% $part_svc->disabled =~ /^Y/i ? ' (DISABLED' : '' %>
    </TD>
  </TR>
% foreach ( 1 .. $columns-1 ) {
%       if ( $count == int( $_ * scalar(@part_svc) / $columns ) ) { 
%  

         </TABLE></TD><TD VALIGN="top"><% $thead %>
%   }
%     }
%     $count++;
%  
% } 


</TR></TABLE></TD></TR></TABLE>
% foreach my $f ( qw( clone pkgnum ) ) { 

  <INPUT TYPE="hidden" NAME="<% $f %>" VALUE="<% $cgi->param($f) %>">
% } 

<INPUT TYPE="hidden" NAME="pkgpart" VALUE="<% $part_pkg->pkgpart %>">
%
%
%# prolly should be in database
%tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };
%
%my %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
%                    split("\n", ($clone_part_pkg||$part_pkg)->plandata );
%#warn join("\n", map { "$_: $plandata{$_}" } keys %plandata ). "\n";
%
%tie my %options, 'Tie::IxHash', map { $_=>$plans{$_}->{'name'} } keys %plans;
%
%#my @form_select = ('classnum');
%#if ( $conf->exists('enable_taxclasses') ) {
%#  push @form_select, 'taxclass';
%#} else {
%#  push @fixups, 'taxclass'; #hidden
%#}
%my @form_elements = ( 'classnum', 'taxclass' );
%# copying non-existant elements is probably harmless, but after 1.7.2
%#my @form_elements = ( 'classnum', 'taxclass', 'agent_type' );
%
%my @form_radio = ();
%if ( dbdef->table('pkg_svc')->column('primary_svc') ) {
%  push @form_radio, 'pkg_svc_primary';
%}
%
%tie my %freq, 'Tie::IxHash', %{FS::part_pkg->freqs_href()};
%if ( $part_pkg->dbdef_table->column('freq')->type =~ /(int)/i ) {
%  delete $freq{$_} foreach grep { ! /^\d+$/ } keys %freq;
%}
%
%my $widget = new HTML::Widgets::SelectLayers(
%  'selected_layer' => $part_pkg->plan,
%  'options'        => \%options,
%  'form_name'      => 'dummy',
%  'form_action'    => 'process/part_pkg.cgi',
%  'form_elements'  => \@form_elements,
%  'form_text'      => [ qw(pkg comment promo_code clone pkgnum pkgpart),
%                        qw(pay_weight credit_weight),
%                        @fixups,
%                      ],
%  'form_checkbox'  => [ qw(setuptax recurtax disabled) ],
%  'form_radio'     => \@form_radio,
%  'layer_callback' => sub {
%    my $layer = shift;
%    my $html = qq!<INPUT TYPE="hidden" NAME="plan" VALUE="$layer">!.
%               ntable("#cccccc",2);
%    $html .= '
%      <TR>
%        <TD ALIGN="right">Recurring fee frequency </TD>
%        <TD><SELECT NAME="freq">
%    ';
%
%    my @freq = keys %freq;
%    @freq = grep { /^\d+$/ } @freq
%      if exists($plans{$layer}->{'freq'}) && $plans{$layer}->{'freq'} eq 'm';
%    foreach my $freq ( @freq ) {
%      $html .= qq(<OPTION VALUE="$freq");
%      $html .= ' SELECTED' if $freq eq $part_pkg->freq;
%      $html .= ">$freq{$freq}";
%    }
%    $html .= '</SELECT></TD></TR>';
%
%    my $href = $plans{$layer}->{'fields'};
%    foreach my $field ( exists($plans{$layer}->{'fieldorder'})
%                          ? @{$plans{$layer}->{'fieldorder'}}
%                          : keys %{ $href }
%                      ) {
%
%      $html .= '<TR><TD ALIGN="right">'. $href->{$field}{'name'}. '</TD><TD>';
%
%      if ( ! exists($href->{$field}{'type'}) ) {
%        $html .= qq!<INPUT TYPE="text" NAME="$field" VALUE="!.
%                 ( exists($plandata{$field})
%                     ? $plandata{$field}
%                     : $href->{$field}{'default'} ).
%                 qq!" onChange="fchanged(this)">!;  #after 1.7.2
%      } elsif ( $href->{$field}{'type'} eq 'checkbox' ) {
%        $html .= qq!<INPUT TYPE="checkbox" NAME="$field" VALUE=1 !.
%                 ( exists($plandata{$field}) && $plandata{$field}
%                   ? ' CHECKED'
%                   : ''
%                 ). '>';
%      } elsif ( $href->{$field}{'type'} =~ /^select/ ) {
%        $html .= '<SELECT';
%        $html .= ' MULTIPLE'
%          if $href->{$field}{'type'} eq 'select_multiple';
%        $html .= qq! NAME="$field" onChange="fchanged(this)">!; # after 1.7.2
%
%        if ( $href->{$field}{'select_table'} ) {
%          foreach my $record (
%            qsearch( $href->{$field}{'select_table'},
%                     $href->{$field}{'select_hash'}   )
%          ) {
%            my $value = $record->getfield($href->{$field}{'select_key'});
%            $html .= qq!<OPTION VALUE="$value"!.
%                     (  $plandata{$field} =~ /(^|, *)$value *(,|$)/
%                          ? ' SELECTED'
%                          : ''
%                     ).
%                     '>'. $record->getfield($href->{$field}{'select_label'});
%          }
%        } elsif ( $href->{$field}{'select_options'} ) {
%          foreach my $key ( keys %{ $href->{$field}{'select_options'} } ) {
%            my $value = $href->{$field}{'select_options'}{$key};
%            $html .= qq!<OPTION VALUE="$key"!.
%                     ( $plandata{$field} =~ /(^|, *)$value *(,|$)/
%                         ? ' SELECTED'
%                         : ''
%                     ).
%                     '>'. $value;
%          }
%
%        } else {
%          $html .= '<font color="#ff0000">warning: '.
%                   "don't know how to retreive options for $field select field".
%                   '</font>';
%        }
%        $html .= '</SELECT>';
%      }
%
%      $html .= '</TD></TR>';
%    }
%    $html .= '</TABLE>';
%
%    $html .= '<INPUT TYPE="hidden" NAME="plandata" VALUE="'.
%             join(',', keys %{ $href } ). '">'.
%             '<BR><BR>';
%             
%    $html .= '<INPUT TYPE="submit" VALUE="'.
%             ( $hashref->{pkgpart} ? "Apply changes" : "Add package" ).
%             '" onClick="fchanged(this)">'; #after 1.7.2
%
%    $html;
%
%  },
%);
%
%


<BR><BR>Price plan <% $widget->html %>
  </BODY>
</HTML>
