<!-- mason kludge -->
<%

if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
  $cgi->param('clone', $1);
} else {
  $cgi->param('clone', '');
}
if ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
  $cgi->param('pkgnum', $1);
} else {
  $cgi->param('pkgnum', '');
}

my ($query) = $cgi->keywords;
my $action = '';
my $part_pkg = '';
if ( $cgi->param('error') ) {
  $part_pkg = new FS::part_pkg ( {
    map { $_, scalar($cgi->param($_)) } fields('part_pkg')
  } );
}
if ( $cgi->param('clone') ) {
  $action='Custom Pricing';
  my $old_part_pkg =
    qsearchs('part_pkg', { 'pkgpart' => $cgi->param('clone') } );
  $part_pkg ||= $old_part_pkg->clone;
  $part_pkg->disabled('Y');
} elsif ( $query && $query =~ /^(\d+)$/ ) {
  $part_pkg ||= qsearchs('part_pkg',{'pkgpart'=>$1});
} else {
  unless ( $part_pkg ) {
    $part_pkg = new FS::part_pkg {};
    $part_pkg->plan('flat');
  }
}
unless ( $part_pkg->plan ) { #backwards-compat
  $part_pkg->plan('flat');
  $part_pkg->plandata("setup_fee=". $part_pkg->setup. "\n".
                      "recur_fee=". $part_pkg->recur. "\n");
}
$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
my $hashref = $part_pkg->hashref;

%>

<%= header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
)) %>

<% #), ' onLoad="visualize()"'); %>

<% if ( $cgi->param('error') ) { %>
  <FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<% #print '<FORM ACTION="', popurl(1), 'process/part_pkg.cgi" METHOD=POST>'; %>

<FORM NAME="dummy">

<%
#if ( $cgi->param('clone') ) {
#  print qq!<INPUT TYPE="hidden" NAME="clone" VALUE="!, $cgi->param('clone'), qq!">!;
#}
#if ( $cgi->param('pkgnum') ) {
#  print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="!, $cgi->param('pkgnum'), qq!">!;
#}
#
#print qq!<INPUT TYPE="hidden" NAME="pkgpart" VALUE="$hashref->{pkgpart}">!,
%>

<%= itable('',8,1) %><TR><TD VALIGN="top">

Package information

<%= ntable("#cccccc",2) %>
  <TR>
    <TD ALIGN="right">Package Definition #</TD>
    <TD BGCOLOR="#ffffff">
      <%= $hashref->{pkgpart} ? $hashref->{pkgpart} : "(NEW)" %>
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Package (customer-visible)</TD>
    <TD>
      <INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="<%= $part_pkg->pkg %>">
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Comment (customer-hidden)</TD>
    <TD>
      <INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="<%=$part_pkg->comment%>">
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right">Disable new orders</TD>
    <TD>
      <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<%= $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>
    </TD>
  </TR>

</TABLE>

</TD><TD VALIGN="top">

Tax information
<%= ntable("#cccccc", 2) %>
  <TR>
    <TD ALIGN="right">Setup fee tax exempt</TD>
    <TD>
<%

print '<INPUT TYPE="checkbox" NAME="setuptax" VALUE="Y"';
print ' CHECKED' if $hashref->{setuptax} eq "Y";
print '>';

print <<END;
</TD></TR>
<TR><TD ALIGN="right">Recurring fee tax exempt</TD><TD>
END

print '<INPUT TYPE="checkbox" NAME="recurtax" VALUE="Y"';
print ' CHECKED' if $hashref->{recurtax} eq "Y";
print '>';

print '</TD></TR>';

my $conf = new FS::Conf;
#false laziness w/ view/cust_main.cgi quick order
if ( $conf->exists('enable_taxclasses') ) {
  print '<TR><TD ALIGN="right">Tax class</TD><TD><SELECT NAME="taxclass">';
  my $sth = dbh->prepare('SELECT DISTINCT taxclass FROM cust_main_county')
    or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  foreach my $taxclass ( map $_->[0], @{$sth->fetchall_arrayref} ) {
    print qq!<OPTION VALUE="$taxclass"!;
    print ' SELECTED' if $taxclass eq $hashref->{taxclass};
    print qq!>$taxclass</OPTION>!;
  }
  print '</SELECT></TD></TR>';
} else {
  print
    '<INPUT TYPE="hidden" NAME="taxclass" VALUE="'. $hashref->{taxclass}. '">';
}

%>

</TABLE>

</TD></TR></TABLE>

<%

my $thead =  "\n\n". ntable('#cccccc', 2).
             '<TR><TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Quan.</FONT></TH>';
$thead .=  '<TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Primary</FONT></TH>'
  if dbdef->table('pkg_svc')->column('primary_svc');
$thead .= '<TH BGCOLOR="#dcdcdc">Service</TH></TR>';

#unless ( $cgi->param('clone') ) {
#dunno why...
unless ( 0 ) {
  #print <<END, $thead;
  print <<END, itable('', 4, 1), '<TR><TD VALIGN="top">', $thead;
<BR><BR>Services included
END
}

my @fixups = ();
my $count = 0;
my $columns = 3;
my @part_svc = qsearch( 'part_svc', { 'disabled' => '' } );
foreach my $part_svc ( @part_svc ) {
  my $svcpart = $part_svc->svcpart;
  my $pkgpart = $cgi->param('clone') || $part_pkg->pkgpart;
  my $pkg_svc = $pkgpart && qsearchs( 'pkg_svc', {
    'pkgpart'  => $pkgpart,
    'svcpart'  => $svcpart,
  } ) || new FS::pkg_svc ( {
    'pkgpart'     => $pkgpart,
    'svcpart'     => $svcpart,
    'quantity'    => 0,
    'primary_svc' => '',
  });
  #? #next unless $pkg_svc;

  push @fixups, "pkg_svc$svcpart";

  #unless ( defined ($cgi->param('clone')) && $cgi->param('clone') ) {
  #dunno why...
  unless ( 0 ) {
    print '<TR>'; # if $count == 0 ;
    print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=4 MAXLENGTH=3 VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0,
          qq!"></TD>!;
    if ( dbdef->table('pkg_svc')->column('primary_svc') ) {
      print qq!<TD><INPUT TYPE="radio" NAME="pkg_svc_primary" VALUE="$svcpart"!;
      print ' CHECKED' if $pkg_svc->primary_svc =~ /^Y/i;
      print '></TD>';
    }
    print qq!<TD><A HREF="part_svc.cgi?!,$part_svc->svcpart,
          qq!">!, $part_svc->getfield('svc'), "</A></TD></TR>";
#    print "</TABLE></TD><TD>$thead" if ++$count == int(scalar(@part_svc) / 2);
    $count+=1;
    foreach ( 1 .. $columns-1 ) {
      print "</TABLE></TD><TD VALIGN=\"top\">$thead"
        if $count == int( $_ * scalar(@part_svc) / $columns );
    }
  } else {
    print qq!<INPUT TYPE="hidden" NAME="pkg_svc$svcpart" VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0, qq!">\n!;
  }
}

#unless ( $cgi->param('clone') ) {
#dunno why...
unless ( 0 ) {
  print "</TR></TABLE></TD></TR></TABLE>";
  #print "</TR></TABLE>";
}

foreach my $f ( qw( clone pkgnum ) ) {
  print qq!<INPUT TYPE="hidden" NAME="$f" VALUE="!. $cgi->param($f). '">';
}
print '<INPUT TYPE="hidden" NAME="pkgpart" VALUE="'. $part_pkg->pkgpart. '">';

# prolly should be in database
tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };

my %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
                    split("\n", $part_pkg->plandata );

tie my %options, 'Tie::IxHash', map { $_=>$plans{$_}->{'name'} } keys %plans;

my @form_select = ();
if ( $conf->exists('enable_taxclasses') ) {
  push @form_select, 'taxclass';
} else {
  push @fixups, 'taxclass'; #hidden
}

my @form_radio = ();
if ( dbdef->table('pkg_svc')->column('primary_svc') ) {
  push @form_radio, 'pkg_svc_primary';
}

tie my %freq, 'Tie::IxHash', %FS::part_pkg::freq;
if ( $part_pkg->dbdef_table->column('freq')->type =~ /(int)/i ) {
  delete $freq{$_} foreach grep { ! /^\d+$/ } keys %freq;
}

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => $part_pkg->plan,
  'options'        => \%options,
  'form_name'      => 'dummy',
  'form_action'    => 'process/part_pkg.cgi',
  'form_text'      => [ qw(pkg comment clone pkgnum pkgpart), @fixups ],
  'form_checkbox'  => [ qw(setuptax recurtax disabled) ],
  'form_radio'     => \@form_radio,
  'form_select'    => \@form_select,
  'layer_callback' => sub {
    my $layer = shift;
    my $html = qq!<INPUT TYPE="hidden" NAME="plan" VALUE="$layer">!.
               ntable("#cccccc",2);
    $html .= '
      <TR>
        <TD ALIGN="right">Recurring fee frequency </TD>
        <TD><SELECT NAME="freq">
    ';

    my @freq = keys %freq;
    @freq = grep { /^\d+$/ } @freq
      if exists($plans{$layer}->{'freq'}) && $plans{$layer}->{'freq'} eq 'm';
    foreach my $freq ( @freq ) {
      $html .= qq(<OPTION VALUE="$freq");
      $html .= ' SELECTED' if $freq eq $part_pkg->freq;
      $html .= ">$freq{$freq}";
    }
    $html .= '</SELECT></TD></TR>';

    my $href = $plans{$layer}->{'fields'};
    foreach my $field ( exists($plans{$layer}->{'fieldorder'})
                          ? @{$plans{$layer}->{'fieldorder'}}
                          : keys %{ $href }
                      ) {

      $html .= '<TR><TD ALIGN="right">'. $href->{$field}{'name'}. '</TD><TD>';

      if ( ! exists($href->{$field}{'type'}) ) {
        $html .= qq!<INPUT TYPE="text" NAME="$field" VALUE="!.
                 ( exists($plandata{$field})
                     ? $plandata{$field}
                     : $href->{$field}{'default'} ).
                 qq!" onChange="fchanged(this)">!;
      } elsif ( $href->{$field}{'type'} eq 'select_multiple' ) {
        $html .= qq!<SELECT MULTIPLE NAME="$field" onChange="fchanged(this)">!;
        foreach my $record (
          qsearch( $href->{$field}{'select_table'},
                   $href->{$field}{'select_hash'}   )
        ) {
          my $value = $record->getfield($href->{$field}{'select_key'});
          $html .= qq!<OPTION VALUE="$value"!.
                   (  $plandata{$field} =~ /(^|, *)$value *(,|$)/
                        ? ' SELECTED'
                        : ''          ).
                   '>'. $record->getfield($href->{$field}{'select_label'})
        }
        $html .= '</SELECT>';
      }

      $html .= '</TD></TR>';
    }
    $html .= '</TABLE>';

    $html .= '<INPUT TYPE="hidden" NAME="plandata" VALUE="'.
             join(',', keys %{ $href } ). '">'.
             '<BR><BR>';
             
    $html .= '<INPUT TYPE="submit" VALUE="'.
             ( $hashref->{pkgpart} ? "Apply changes" : "Add package" ).
             '" onClick="fchanged(this)">';

    $html;

  },
);

%>

<BR><BR>Price plan <%= $widget->html %>
  </BODY>
</HTML>
