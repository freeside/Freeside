<!-- $Id: part_pkg.cgi,v 1.6 2001-10-20 12:17:59 ivan Exp $ -->

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
} elsif ( $query && $query =~ /^(\d+)$/ ) {
  $part_pkg ||= qsearchs('part_pkg',{'pkgpart'=>$1});
} else {
  $part_pkg ||= new FS::part_pkg {};
  $part_pkg->plan('flat');
}
unless ( $part_pkg->plan ) { #backwards-compat
  $part_pkg->plan('flat');
  $part_pkg->plandata("setup_fee=". $part_pkg->setup. "\n".
                      "recur_fee=". $part_pkg->recur. "\n");
}
$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
my $hashref = $part_pkg->hashref;

%>

<SCRIPT>
function visualize(what) {
  if (document.getElementById) {
    document.getElementById('d<%= $part_pkg->plan %>').style.visibility = "visible";
  } else {
    document.l<%= $part_pkg->plan %>.visibility = "visible";
  }
}
</SCRIPT>

<% 

print header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
), ' onLoad="visualize()"');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

#print '<FORM ACTION="', popurl(1), 'process/part_pkg.cgi" METHOD=POST>';
print '<FORM NAME="dummy">';

#if ( $cgi->param('clone') ) {
#  print qq!<INPUT TYPE="hidden" NAME="clone" VALUE="!, $cgi->param('clone'), qq!">!;
#}
#if ( $cgi->param('pkgnum') ) {
#  print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="!, $cgi->param('pkgnum'), qq!">!;
#}
#
#print qq!<INPUT TYPE="hidden" NAME="pkgpart" VALUE="$hashref->{pkgpart}">!,
print "Package Part #", $hashref->{pkgpart} ? $hashref->{pkgpart} : "(NEW)";

print itable("#cccccc",2), <<END;
<TR><TD ALIGN="right">Package (customer-visable)</TD><TD><INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="$hashref->{pkg}"></TD></TR>
<TR><TD ALIGN="right">Comment (customer-hidden)</TD><TD><INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="$hashref->{comment}"></TD></TR>
<TR><TD ALIGN="right">Frequency (months) of recurring fee</TD><TD><INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}" SIZE=3></TD></TR>
<TR><TD ALIGN="right">Setup fee tax exempt</TD><TD>
END

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

print '</TD></TR></TABLE>';

my $thead =  "\n\n". ntable('#cccccc', 2). <<END;
<TR><TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Quan.</FONT></TH><TH BGCOLOR="#dcdcdc">Service</TH></TR>
END

unless ( $cgi->param('clone') ) {
  #print <<END, $thead;
  print <<END, itable(), '<TR><TD VALIGN="top">', $thead;
<BR><BR>Enter the quantity of each service this package includes.<BR><BR>
END
}

my @fixups = ();
my $count = 0;
my $columns = 3;
my @part_svc = qsearch( 'part_svc', {} );
foreach my $part_svc ( @part_svc ) {
  my $svcpart = $part_svc->svcpart;
  my $pkg_svc = qsearchs( 'pkg_svc', {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
  } ) || new FS::pkg_svc ( {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
    'quantity' => 0,
  });
  #? #next unless $pkg_svc;

  push @fixups, "pkg_svc$svcpart";

  unless ( defined ($cgi->param('clone')) && $cgi->param('clone') ) {
    print '<TR>'; # if $count == 0 ;
    print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=4 MAXLENGTH=3 VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0,
          qq!"></TD><TD><A HREF="part_svc.cgi?!,$part_svc->svcpart,
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

unless ( $cgi->param('clone') ) {
  print "</TR></TABLE></TD></TR></TABLE>";
  #print "</TR></TABLE>";
}

# prolly should be in database
my %plans = (

  'flat' => {
    'name' => 'Flat rate',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'setup' => 'what.setup_fee.value',
    'recur' => 'what.recur_fee.value',
  },

  'flat_comission' => {
    'name' => 'Flat rate with recurring referral comission as credit',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                     },
      'comission_amount' => { 'name' => 'Comission amount',
                              'default' => 0,
                            },
      'comission_depth'  => { 'name' => 'Number of layers',
                              'default' => 1,
                            },
    },
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  },

);

%>

<SCRIPT>
var layer = null;

function changed(what) {
  layer = what.options[what.selectedIndex].value;
<% foreach my $layer ( keys %plans ) { %>
  if (layer == "<%= $layer %>" ) {
    <% foreach my $not ( grep { $_ ne $layer } keys %plans ) { %>
      if (document.getElementById) {
        document.getElementById('d<%= $not %>').style.visibility = "hidden";
      } else {
        document.l<%= $not %>.visibility = "hidden";
      }
    <% } %>
    if (document.getElementById) {
      document.getElementById('d<%= $layer %>').style.visibility = "visible";
    } else {
      document.l<%= $layer %>.visibility = "visible";
    }
  }
<% } %>
}

</SCRIPT>
<BR>
Price plan <SELECT NAME="plan" SIZE=1 onChange="changed(this);">
<OPTION>
<% foreach my $layer (keys %plans ) { %>
<OPTION VALUE="<%= $layer %>"<%= ' SELECTED'x($layer eq $part_pkg->plan) %>><%= $plans{$layer}->{'name'} %>
<% } %>
</SELECT></FORM>

<SCRIPT>
function fchanged(what) {
  fixup(what.form);
}

function fixup(what) {
<% foreach my $f ( qw( pkg comment freq ), @fixups ) { %>
  what.<%= $f %>.value = document.dummy.<%= $f %>.value;
<% } %>
<% foreach my $f ( qw( setuptax recurtax ) ) { %>
  if (document.dummy.<%= $f %>.checked)
    what.<%= $f %>.value = 'Y';
  else
    what.<%= $f %>.value = '';
<% } %>
  what.plan.value = document.dummy.plan.options[document.dummy.plan.selectedIndex].value;
<% foreach my $p ( keys %plans ) { %>
  if ( what.plan.value == "<%= $p %>" ) {
    what.setup.value = <%= $plans{$p}->{setup} %>;
    what.recur.value = <%= $plans{$p}->{recur} %>;
  }
<% } %>
}
</SCRIPT>

<% my %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
                    split("\n", $part_pkg->plandata );
   #foreach my $layer ( 'konq_kludge', keys %plans ) { 
   foreach my $layer ( 'konq_kludge', keys %plans ) {
     my $visibility = "hidden";
%>
<SCRIPT>
if (document.getElementById) {
    document.write("<DIV ID=\"d<%= $layer %>\" STYLE=\"visibility: <%= $visibility %>; position: absolute\">");
} else {
<% $visibility="show" if $visibility eq "visible"; %>
    document.write("<LAYER ID=\"l<%= $layer %>\" VISIBILITY=\"<%= $visibility %>\">");
}
</SCRIPT>

<FORM NAME="<%= $layer %>" ACTION="process/part_pkg.cgi" METHOD=POST onSubmit="fixup(this)">
<INPUT TYPE="hidden" NAME="plan" VALUE="<%= $part_pkg->plan %>">
<INPUT TYPE="hidden" NAME="pkg" VALUE="<%= $hashref->{pkg} %>">
<INPUT TYPE="hidden" NAME="comment" VALUE="$<%= $hashref->{comment} %>">
<INPUT TYPE="hidden" NAME="freq" VALUE="<%= $hashref->{freq} %>">
<INPUT TYPE="hidden" NAME="setuptax" VALUE="<%= $hashref->{setuptax} %>">
<INPUT TYPE="hidden" NAME="recurtax" VALUE="<%= $hashref->{recurtax} %>">
<% foreach my $f ( @fixups ) { %>
<INPUT TYPE="hidden" NAME="<%= $f %>" VALUE="">
<% } %>

<%
if ( $cgi->param('clone') ) {
  print qq!<INPUT TYPE="hidden" NAME="clone" VALUE="!, $cgi->param('clone'), qq!">!;
}
if ( $cgi->param('pkgnum') ) {
  print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="!, $cgi->param('pkgnum'), qq!">!;
}
%>

<INPUT TYPE="hidden" NAME="pkgpart" VALUE="<%= $hashref->{pkgpart} %>">
<%= itable("#cccccc",2) %>

<% my $href = $plans{$layer}->{'fields'};
   foreach my $field ( keys %{ $href } ) { %>
<TR><TD ALIGN="right"><%= $href->{$field}{'name'} %></TD>
<TD><INPUT TYPE="text" NAME="<%= $field %>" VALUE="<%= exists($plandata{$field}) ? $plandata{$field} : $href->{$field}{'default'} %>" onChange="fchanged(this)"></TD></TR>
<% } %>
</TABLE>
<INPUT TYPE="hidden" NAME="plandata" VALUE="<%= join(',', keys %{ $href } ) %>">
<FONT SIZE="1">
<BR><BR>
Setup expression<BR><INPUT TYPE="text" NAME="setup" SIZE="160" VALUE="<%= $hashref->{setup} %>" onLoad="fchanged(this)"><BR>
Recurring espression<BR><INPUT TYPE="text" NAME="recur" SIZE="160" VALUE="<%= $hashref->{recur} %>" onLoad="fchanged(this)"><BR>
</FONT>

<%
print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{pkgpart} ? "Apply changes" : "Add package",
      qq!" onClick="fchanged(this)">!;
%>

</FORM>

<SCRIPT>
if (document.getElementById) {
  document.write("</DIV>");
} else {
  document.write("</LAYER>");
}
</SCRIPT>

<% } %>

<TAG onLoad="
    if (document.getElementById) {
      document.getElementById('d<%= $part_pkg->plan %>').style.visibility = 'visible';
    } else {
      document.l<%= $part_pkg->plan %>.visibility = 'visible';
    }
">
  </BODY>
</HTML>
