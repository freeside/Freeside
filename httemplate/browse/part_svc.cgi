<!-- mason kludge -->
<% 

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
<%= table() %>
  <TR>
    <TH COLSPAN=<%= $cgi->param('showdisabled') ? 2 : 3 %>>Service</TH>
    <TH>Table</TH>
    <TH>Export</TH>
    <TH>Field</TH>
    <TH COLSPAN=2>Modifier</TH>
  </TR>

<% foreach my $part_svc ( @part_svc ) {
     my $hashref = $part_svc->hashref;
     my $svcdb = $hashref->{svcdb};
     my @dfields = fields($svcdb);
     push @dfields, 'usergroup' if $svcdb eq 'svc_acct'; #kludge
     my @fields =
       grep { $_ ne 'svcnum' && $part_svc->part_svc_column($_)->columnflag }
            @dfields;

     my $rowspan = scalar(@fields) || 1;
     my $url = "${p}edit/part_svc.cgi?$hashref->{svcpart}";
%>

  <TR>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $hashref->{svcpart} %></A></TD>
<% unless ( $cgi->param('showdisabled') ) { %>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $hashref->{disabled} ? 'DISABLED' : '' %></TD>
<% } %>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $hashref->{svc} %></A></TD>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $hashref->{svcdb} %></TD>
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
     <%= $n1 %><TD><%= $field %></TD><TD>

<%     if ( $flag eq "D" ) { print "Default"; }
         elsif ( $flag eq "F" ) { print "Fixed"; }
         else { print "(Unknown!)"; }
%>
       </TD><TD><%= $part_svc->part_svc_column($field)->columnvalue%></TD>
<%     $n1="</TR><TR>";
     }
%>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>
