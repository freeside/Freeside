<!-- $Id: part_pkg.cgi,v 1.3 2001-10-11 17:44:33 ivan Exp $ -->

<% my $plan = 'flat'; %>

<SCRIPT>
function visualize(what) {
  if (document.getElementById) {
    document.getElementById('d<%= $plan %>').style.visibility = "visible";
  } else {
    document.l<%= $plan %>.visibility = "visible";
  }
}
</SCRIPT>

<%

$cgi = new CGI;

&cgisuidsetup($cgi);

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
}
$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
my $hashref = $part_pkg->hashref;

print header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
));

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

print <<END;
<PRE>
Package (customer-visable)          <INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="$hashref->{pkg}">
Comment (customer-hidden)           <INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="$hashref->{comment}">

Frequency (months) of recurring fee <INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}">

</PRE>

END

unless ( $cgi->param('clone') ) {
  print <<END;
Enter the quantity of each service this package includes.<BR><BR>
<TABLE BORDER><TR><TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH>
		  <TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH></TR>
END
}

my $count = 0;
my @fixups = ();
foreach my $part_svc ( ( qsearch( 'part_svc', {} ) ) ) {
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
    print '<TR>' if $count == 0 ;
    print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=3 VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0,
          qq!"></TD><TD><A HREF="part_svc.cgi?!,$part_svc->svcpart,
          qq!">!, $part_svc->getfield('svc'), "</A></TD>";
    $count++;
    if ($count == 2)
    {
      print '</TR>';
      $count = 0;
    }
  } else {
    print qq!<INPUT TYPE="hidden" NAME="pkg_svc$svcpart" VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0, qq!">\n!;
  }
}

unless ( $cgi->param('clone') ) {
  print qq!</TR>! if ($count != 0) ;
  print "</TABLE>";
}

# prolly should be in database
my %plans = (

  'flat' => {
    'name' => 'Flat rate',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package' },
      'recur_fee' => { 'name' => 'Recurring fee for this package' },
    },
    'setup' => 'what.setup_fee.value',
    'recur' => 'what.recur_fee.value',
  },

  'flat_comission' => {
    'name' => 'Flat rate with recurring referral comission as credit',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package' },
      'recur_fee' => { 'name' => 'Recurring fee for this package' },
      'comission_amount' => { 'name' => 'Comission amount' },
      'comission_depth' => { 'name' => 'Number of layers' },
    },
    'setup' => 'what.setup_fee.value',
    'recur' => '\'$cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ) ; \' + what.recur_fee.value + \';\'',
  },

);

%>

<SCRIPT>
var svcdb = null;
var something = null;

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
Price plan <SELECT NAME="plan" SIZE=1 onChange="changed(this)">
<% foreach my $layer (keys %plans ) { %>
<OPTION VALUE="<%= $layer %>"<%= ' SELECTED'x($layer eq $plan) %>><%= $plans{$layer}->{'name'} %>
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
  what.plan.value = document.dummy.plan.options[document.dummy.plan.selectedIndex].value;
<% foreach my $p ( keys %plans ) { %>
  if ( what.plan.value == "<%= $p %>" ) {
    what.setup.value = <%= $plans{$p}->{setup} %>;
    what.recur.value = <%= $plans{$p}->{recur} %>;
  }
<% } %>
}
</SCRIPT>

<% #foreach my $layer ( 'konq_kludge', keys %plans ) { 
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
<INPUT TYPE="hidden" NAME="plan" VALUE="<%= $plan %>">
<INPUT TYPE="hidden" NAME="pkg" VALUE="<%= $hashref->{pkg} %>">
<INPUT TYPE="hidden" NAME="comment" VALUE="$<%= hashref->{comment} %>">
<INPUT TYPE="hidden" NAME="freq" VALUE="<%= $hashref->{freq} %>">
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
print qq!<INPUT TYPE="hidden" NAME="pkgpart" VALUE="$hashref->{pkgpart}">!,
%>

<% my $href = $plans{$layer}->{'fields'};
   foreach my $field ( keys %{ $href } ) { %>
<%= $href->{$field}{'name'} %>: 
<INPUT TYPE="text" NAME="<%= $field %>" VALUE="<%= $ref->{$field}{'default'} %>" onChange="fchanged(this)"><BR>
<% } %>

<FONT SIZE="-2">
Setup expression                    <INPUT TYPE="text" NAME="setup" SIZE="100%" VALUE="<%= $hashref->{setup} %>"><BR>
Recurring espression                <INPUT TYPE="text" NAME="recur" SIZE="100%" VALUE="<%= $hashref->{recur} %>"><BR>
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
      document.getElementById('d<%= $plan %>').style.visibility = 'visible';
    } else {
      document.l<%= $plan %>.visibility = 'visible';
    }
">
  </BODY>
</HTML>
