<!-- mason kludge -->
<%

# If it's stupid but it works, it's still stupid.
#  -Kristian


use HTML::Widgets::SelectLayers;
use Tie::IxHash;

my( $svcnum,  $pkgnum, $svcpart, $part_svc, $svc_broadband );
if ( $cgi->param('error') ) {
  $svc_broadband = new FS::svc_broadband ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_broadband'), qw(svcpart)
  } );
  $svcnum = $svc_broadband->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $svc_broadband->svcpart;
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_broadband=qsearchs('svc_broadband',{'svcnum'=>$svcnum})
      or die "Unknown (svc_broadband) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svc_broadband = new FS::svc_broadband({ svcpart => $svcpart });

    $svcnum='';

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_broadband->setfield( $part_svc_column->columnname,
                                $part_svc_column->columnvalue,
                              );
    }

  }
}
my $action = $svc_broadband->svcnum ? 'Edit' : 'Add';

if ($pkgnum) {

  #Nothing?

} elsif ( $action eq 'Edit' ) {

  #Nothing?

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

my $p1 = popurl(1);

my ($ip_addr, $speed_up, $speed_down, $blocknum) =
    ($svc_broadband->ip_addr,
     $svc_broadband->speed_up,
     $svc_broadband->speed_down,
     $svc_broadband->blocknum);

%>

<%=header("Broadband Service $action", '')%>

<% if ($cgi->param('error')) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%=$cgi->param('error')%></FONT><BR>
<% } %>

Service #<B><%=$svcnum ? $svcnum : "(NEW)"%></B><BR><BR>

<FORM ACTION="<%=${p1}%>process/svc_broadband.cgi" METHOD=POST>
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%=$svcnum%>">
  <INPUT TYPE="hidden" NAME="pkgnum" VALUE="<%=$pkgnum%>">
  <INPUT TYPE="hidden" NAME="svcpart" VALUE="<%=$svcpart%>">

  <%=&ntable("#cccccc",2)%>
    <TR>
      <TD ALIGN="right">IP Address</TD>
      <TD BGCOLOR="#ffffff">
<% if ( $part_svc->part_svc_column('ip_addr')->columnflag eq 'F' ) { %>
        <INPUT TYPE="hidden" NAME="ip_addr" VALUE="<%=$ip_addr%>"><%=$ip_addr%>
<% } else { %>
        <INPUT TYPE="text" NAME="ip_addr" VALUE="<%=$ip_addr%>">
<% } %>
      </TD>
    </TR>
    <TR>
      <TD ALIGN="right">Download speed</TD>
      <TD BGCOLOR="#ffffff">
<% if ( $part_svc->part_svc_column('speed_down')->columnflag eq 'F' ) { %>
        <INPUT TYPE="hidden" NAME="speed_down" VALUE="<%=$speed_down%>"><%=$speed_down%>Kbps
<% } else { %>
    <INPUT TYPE="text" NAME="speed_down" SIZE=5 VALUE="<%=$speed_down%>">Kbps
<% } %>
      </TD>
    </TR>
    <TR>
      <TD ALIGN="right">Upload speed</TD>
      <TD BGCOLOR="#ffffff">
<% if ( $part_svc->part_svc_column('speed_up')->columnflag eq 'F' ) { %>
        <INPUT TYPE="hidden" NAME="speed_up" VALUE="<%=$speed_up%>"><%=$speed_up%>Kbps
<% } else { %>
        <INPUT TYPE="text" NAME="speed_up" SIZE=5 VALUE="<%=$speed_up%>">Kbps
<% } %>
      </TD>
    </TR>
<% if ($action eq 'Add') { %>
    <TR>
      <TD ALIGN="right">Router/Block</TD>
      <TD BGCOLOR="#ffffff">
        <SELECT NAME="blocknum">
<%
  warn $svc_broadband->svcpart;
  foreach my $router ($svc_broadband->allowed_routers) {
    warn $router->routername;
    foreach my $addr_block ($router->addr_block) {
%>
        <OPTION VALUE="<%=$addr_block->blocknum%>"<%=($addr_block->blocknum eq $blocknum) ? ' SELECTED' : ''%>>
          <%=$router->routername%>:<%=$addr_block->ip_gateway%>/<%=$addr_block->ip_netmask%></OPTION>
<%
    }
  }
%>
        </SELECT>
      </TD>
    </TR>
<% } else { %>

    <TR>
      <TD ALIGN="right">Router/Block</TD>
      <TD BGCOLOR="#ffffff">
        <%=$svc_broadband->addr_block->router->routername%>:<%=$svc_broadband->addr_block->NetAddr%>
        <INPUT TYPE="hidden" NAME="blocknum" VALUE="<%=$svc_broadband->blocknum%>">
      </TD>
    </TR>

<% } %>

<%
foreach my $field ($svc_broadband->virtual_fields) {
  if ( $part_svc->part_svc_column($field)->columnflag ne 'F' &&
       $part_svc->part_svc_column($field)->columnflag ne 'X') {
    print $svc_broadband->pvf($field)->widget('HTML', 'edit',
        $svc_broadband->getfield($field));
  }
} %>
  </TABLE>
  <BR>
  <INPUT TYPE="submit" NAME="submit" VALUE="Submit">
</FORM>
</BODY>
</HTML>

