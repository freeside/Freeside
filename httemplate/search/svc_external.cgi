<%

my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my(@svc_external,$sortby);
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_external=qsearch('svc_external',{});
} elsif ( $query eq 'id' ) {
  $sortby=\*id_sort;
  @svc_external=qsearch('svc_external',{});
} elsif ( $query eq 'UN_svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_external = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_external',{});
} elsif ( $query eq 'UN_id' ) {
  $sortby=\*id_sort;
  @svc_external = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_external',{});
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  @svc_external =
    qsearch( 'svc_external', {}, '',
               " WHERE $1 = ( SELECT svcpart FROM cust_svc ".
               "              WHERE cust_svc.svcnum = svc_external.svcnum ) "
    );
  $sortby=\*svcnum_sort;
} else {
  $cgi->param('id') =~ /^([\w\-\.]+)$/; 
  my($id)=$1;
  #push @svc_domain, qsearchs('svc_domain',{'domain'=>$domain});
  @svc_external = qsearchs('svc_external',{'id'=>$id});
}

if ( scalar(@svc_external) == 1 ) {
  print $cgi->redirect(popurl(2). "view/svc_external.cgi?". $svc_external[0]->svcnum);
  #exit;
} elsif ( scalar(@svc_external) == 0 ) {
%>
<!-- mason kludge -->
<%
  eidiot "No matching external services found!\n";
} else {
%>
<!-- mason kludge -->
<%= header("External Search Results",'') %>

    <%= scalar(@svc_external) %> matching external services found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH><%= FS::Msgcat::_gettext('svc_external-id') || 'External&nbsp;ID' %></TH>
        <TH><%= FS::Msgcat::_gettext('svc_external-title') || 'Title' %></TH>
      </TR>

<%
  foreach my $svc_external (
    sort $sortby (@svc_external)
  ) {
    my($svcnum, $id, $title)=(
      $svc_external->svcnum,
      $svc_external->id,
      $svc_external->title,
    );

    my $rowspan = 1;

    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$svcnum</A></TD>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$id</A></TD>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$title</A></TD>
END

    #print @rows;
    print "</TR>";

  }
 
  print <<END;
    </TABLE>
  </BODY>
</HTML>
END

}

sub svcnum_sort {
  $a->getfield('svcnum') <=> $b->getfield('svcnum');
}

sub id_sort {
  $a->getfield('id') <=> $b->getfield('id');
}

%>
