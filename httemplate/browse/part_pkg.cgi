<!-- mason kludge -->
<%

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_pkg = qsearch('part_pkg', \%search );
my $total = scalar(@part_pkg);

my $sortby;
my %num_active_cust_pkg = ();
my( $suspended_sth, $canceled_sth ) = ( '', '' );
if ( $cgi->param('active') ) {
  my $active_sth = dbh->prepare(
    'SELECT COUNT(*) FROM cust_pkg WHERE pkgpart = ?'.
    ' AND ( cancel IS NULL OR cancel = 0 )'.
    ' AND ( susp IS NULL OR susp = 0 )'
  ) or die dbh->errstr;
  foreach my $part_pkg ( @part_pkg ) {
    $active_sth->execute($part_pkg->pkgpart) or die $active_sth->errstr;
    $num_active_cust_pkg{$part_pkg->pkgpart} =
      $active_sth->fetchrow_arrayref->[0];
  }
  $sortby = sub {
    $num_active_cust_pkg{$b->pkgpart} <=> $num_active_cust_pkg{$a->pkgpart};
  };

  $suspended_sth = dbh->prepare(
    'SELECT COUNT(*) FROM cust_pkg WHERE pkgpart = ?'.
    ' AND ( cancel IS NULL OR cancel = 0 )'.
    ' AND susp IS NOT NULL AND susp != 0'
  ) or die dbh->errstr;

  $canceled_sth = dbh->prepare(
    'SELECT COUNT(*) FROM cust_pkg WHERE pkgpart = ?'.
    ' AND cancel IS NOT NULL AND cancel != 0'
  ) or die dbh->errstr;

} else {
  $sortby = sub { $a->pkgpart <=> $b->pkgpart; };
}

my $conf = new FS::Conf;
my $taxclasses = $conf->exists('enable_taxclasses');

%>
<%= header("Package Definition Listing",menubar( 'Main Menu' => $p )) %>
<% unless ( $cgi->param('active') ) { %>
  One or more service definitions are grouped together into a package 
  definition and given pricing information.  Customers purchase packages
  rather than purchase services directly.<BR><BR>
  <A HREF="<%= $p %>edit/part_pkg.cgi"><I>Add a new package definition</I></A>
  <BR><BR>
<% } %>

<%= $total %> package definitions
<% if ( $cgi->param('showdisabled') ) { $cgi->param('showdisabled', 0); %>
  ( <a href="<%= $cgi->self_url %>">hide disabled packages</a> )
<% } else { $cgi->param('showdisabled', 1); %>
  ( <a href="<%= $cgi->self_url %>">show disabled packages</a> )!;
<% } %>

<% my $colspan = $cgi->param('showdisabled') ? 2 : 3; %>

<%= &table() %>
      <TR>
        <TH COLSPAN=<%= $colspan %>>Package</TH>
        <TH>Comment</TH>
<% if ( $cgi->param('active') ) { %>
        <TH><FONT SIZE=-1>Customer<BR>packages</FONT></TH>
<% } %>
        <TH><FONT SIZE=-1>Freq.</FONT></TH>
<% if ( $taxclasses ) { %>
	<TH><FONT SIZE=-1>Taxclass</FONT></TH>
<% } %>
        <TH><FONT SIZE=-1>Plan</FONT></TH>
        <TH><FONT SIZE=-1>Data</FONT></TH>
        <TH>Service</TH>
        <TH><FONT SIZE=-1>Quan.</FONT></TH>
<% if ( dbdef->table('pkg_svc')->column('primary_svc') ) { %>
        <TH><FONT SIZE=-1>Primary</FONT></TH>
<% } %>

      </TR>

<%
foreach my $part_pkg ( sort $sortby @part_pkg ) {
  my($hashref)=$part_pkg->hashref;
  my(@pkg_svc)=grep $_->getfield('quantity'),
    qsearch('pkg_svc',{'pkgpart'=> $hashref->{pkgpart} });
  my($rowspan)=scalar(@pkg_svc);
  my $plandata;
  if ( $hashref->{plan} ) {
    $plandata = $hashref->{plandata};
    $plandata =~ s/^(\w+)=/$1&nbsp;/mg;
    $plandata =~ s/\n/<BR>/g;
  } else {
    $hashref->{plan} = "(legacy)";
    $plandata = "Setup&nbsp;". $hashref->{setup}.
                "<BR>Recur&nbsp;". $hashref->{recur};
  }
%>
      <TR>
        <TD ROWSPAN=<%= $rowspan %>><A HREF="<%=$p%>edit/part_pkg.cgi?<%= $hashref->{pkgpart} %>"><%= $hashref->{pkgpart} %></A></TD>

<% unless ( $cgi->param('showdisabled') ) { %>
        <TD ROWSPAN=<%= $rowspan %>>
   <% if ( $hashref->{disabled} ) { %>
          DISABLED
   <% } %>
        </TD>
<% } %>

        <TD ROWSPAN=<%= $rowspan %>><A HREF="<%=$p%>edit/part_pkg.cgi?<%= $hashref->{pkgpart} %>"><%= $hashref->{pkg} %></A></TD>
        <TD ROWSPAN=<%= $rowspan %>><%= $hashref->{comment} %></TD>

<% if ( $cgi->param('active') ) { %>
        <TD ROWSPAN=<%= $rowspan %>>
          <FONT COLOR="#00CC00"><B><%= $num_active_cust_pkg{$hashref->{'pkgpart'}} %></B></FONT>&nbsp;<A HREF="<%=$p%>search/cust_pkg.cgi?magic=active;pkgpart=<%= $hashref->{pkgpart} %>">active</A><BR>

   <% $suspended_sth->execute( $part_pkg->pkgpart )
        or die $suspended_sth->errstr;
      my $num_suspended = $suspended_sth->fetchrow_arrayref->[0];
   %>
          <FONT COLOR="#FF9900"><B><%= $num_suspended %></B></FONT>&nbsp;<A HREF="<%=$p%>search/cust_pkg.cgi?magic=suspended;pkgpart=<%= $hashref->{pkgpart} %>">suspended</A><BR>

   <% $canceled_sth->execute( $part_pkg->pkgpart )
        or die $canceled_sth->errstr;
      my $num_canceled = $canceled_sth->fetchrow_arrayref->[0];
   %>
          <FONT COLOR="#FF0000"><B><%= $num_canceled %></B></FONT>&nbsp;<A HREF="<%=$p%>search/cust_pkg.cgi?magic=canceled;pkgpart=<%= $hashref->{pkgpart} %>">canceled</A>
        </TD>
<% } %>

        <TD ROWSPAN=<%= $rowspan %>><%= $hashref->{freq} %></TD>

<% if ( $taxclasses ) { %>
	<TD ROWSPAN=<%= $rowspan %>><%= $hashref->{taxclass} || '&nbsp;' %></TD>
<% } %>

        <TD ROWSPAN=<%= $rowspan %>><%= $hashref->{plan} %></TD>
        <TD ROWSPAN=<%= $rowspan %>><%= $plandata %></TD>

<%
  my($pkg_svc);
  my($n)="";
  foreach $pkg_svc ( @pkg_svc ) {
    my($svcpart)=$pkg_svc->getfield('svcpart');
    my($part_svc) = qsearchs('part_svc',{'svcpart'=> $svcpart });
    print $n,qq!<TD><A HREF="${p}edit/part_svc.cgi?$svcpart">!,
          $part_svc->getfield('svc'),"</A></TD><TD>",
          $pkg_svc->getfield('quantity'),"</TD>";
    if ( dbdef->table('pkg_svc')->column('primary_svc') ) {
      print '<TD>';
      print 'PRIMARY' if $pkg_svc->primary_svc =~ /^Y/i;
      print '</TD>';
    }
    print "</TR>\n";
    $n="<TR>";
  }
%>

      </TR>
<% } %>

    </TABLE>
  </BODY>
</HTML>
