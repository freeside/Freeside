<% 

my %flag = (
  'D' => 'Default',
  'F' => 'Fixed',
  ''  => '',
);

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_svc =
  sort { $a->getfield('svcpart') <=> $b->getfield('svcpart') }
    qsearch('part_svc', \%search );
my $total = scalar(@part_svc);

my %num_active_cust_svc = map { $_->svcpart => $_->num_cust_svc } @part_svc;

if ( $cgi->param('orderby') eq 'active' ) {
  @part_svc = sort { $num_active_cust_svc{$b->svcpart} <=>
                     $num_active_cust_svc{$a->svcpart}     } @part_svc;
} elsif ( $cgi->param('orderby') eq 'svc' ) { 
  @part_svc = sort { lc($a->svc) cmp lc($b->svc) } @part_svc;
}

%>
<%= header('Service Definition Listing', menubar( 'Main Menu' => $p) ) %>

<SCRIPT>
function part_export_areyousure(href) {
  if (confirm("Are you sure you want to delete this export?") == true)
    window.location.href = href;
}
</SCRIPT>

    Service definitions are the templates for items you offer to your customers.<BR><BR>

<FORM METHOD="POST" ACTION="<%= $p %>edit/part_svc.cgi">
<A HREF="<%= $p %>edit/part_svc.cgi"><I>Add a new service definition</I></A><% if ( @part_svc ) { %>&nbsp;or&nbsp;<SELECT NAME="clone"><OPTION></OPTION>
<% foreach my $part_svc ( @part_svc ) { %>
  <OPTION VALUE="<%= $part_svc->svcpart %>"><%= $part_svc->svc %></OPTION>
<% } %>
</SELECT><INPUT TYPE="submit" VALUE="Clone existing service">
<% } %>
</FORM><BR>

<%= $total %> service definitions
<%= $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled services</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled services</a> )'; }
%>
<% $cgi->param('showdisabled', ( 1 ^ $cgi->param('showdisabled') ) ); %>
<%= table() %>
  <TR>
    <TH><A HREF="<%= do { $cgi->param('orderby', 'svcpart'); $cgi->self_url } %>">#</A></TH>
    <% if ( $cgi->param('showdisabled') ) { %>
      <TH>Status</TH>
    <% } %>
    <TH><A HREF="<%= do { $cgi->param('orderby', 'svc'); $cgi->self_url; } %>">Service</A></TH>
    <TH>Table</TH>
    <TH><A HREF="<%= do { $cgi->param('orderby', 'active'); $cgi->self_url; } %>"><FONT SIZE=-1>Customer<BR>Services</FONT></A></TH>
    <TH>Export</TH>
    <TH>Field</TH>
    <TH COLSPAN=2>Modifier</TH>
  </TR>

<% foreach my $part_svc ( @part_svc ) {
     my $svcdb = $part_svc->svcdb;
     my $svc_x = "FS::$svcdb"->new( { svcpart => $part_svc->svcpart } );
     my @dfields = $svc_x->fields;
     push @dfields, 'usergroup' if $svcdb eq 'svc_acct'; #kludge
     my @fields =
       grep { $svc_x->pvf($_)
           or $_ ne 'svcnum' && $part_svc->part_svc_column($_)->columnflag }
            @dfields ;
     my $rowspan = scalar(@fields) || 1;
     my $url = "${p}edit/part_svc.cgi?". $part_svc->svcpart;
%>

  <TR>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $part_svc->svcpart %></A></TD>
<% if ( $cgi->param('showdisabled') ) { %>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $part_svc->disabled
            ? '<FONT COLOR="#FF0000"><B>Disabled</B></FONT>'
            : '<FONT COLOR="#00CC00"><B>Enabled</B></FONT>'
      %>
    </TD>
<% } %>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $part_svc->svc %></A></TD>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $svcdb %></TD>
    <TD ROWSPAN=<%= $rowspan %>>
      <FONT COLOR="#00CC00"><B><%= $num_active_cust_svc{$part_svc->svcpart} %></B></FONT>&nbsp;<A HREF="<%=$p%>search/<%= $svcdb %>.cgi?svcpart=<%= $part_svc->svcpart %>">active</A>
      <% if ( $num_active_cust_svc{$part_svc->svcpart} ) { %>
        <BR><FONT SIZE="-1">[ <A HREF="<%=$p%>edit/bulk-cust_svc.html?svcpart=<%= $part_svc->svcpart %>">change</A> ]</FONT>
      <% } %>
    </TD>
    <TD ROWSPAN=<%= $rowspan %>><%= itable() %>
<%
#  my @part_export =
map { qsearchs('part_export', { exportnum => $_->exportnum } ) } qsearch('export_svc', { svcpart => $part_svc->svcpart } ) ;
  foreach my $part_export (
    map { qsearchs('part_export', { exportnum => $_->exportnum } ) } 
      qsearch('export_svc', { svcpart => $part_svc->svcpart } )
  ) {
%>
      <TR>
        <TD><A HREF="<%= $p %>edit/part_export.cgi?<%= $part_export->exportnum %>"><%= $part_export->exportnum %>:&nbsp;<%= $part_export->exporttype %>&nbsp;to&nbsp;<%= $part_export->machine %></A></TD></TR>
<%  } %>
      </TABLE></TD>

<%   my($n1)='';
     foreach my $field ( @fields ) {
       my $flag = $part_svc->part_svc_column($field)->columnflag;
%>
     <%= $n1 %>
     <TD><%= $field %></TD>
     <TD><%= $flag{$flag} %></TD>
     <TD><%= $part_svc->part_svc_column($field)->columnvalue%></TD>

<%     $n1="</TR><TR>";
     }
%>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>
