<%

my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my(@svc_forward,$sortby);
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_forward=qsearch('svc_forward',{});
} else {
  eidiot('unimplemented');
}

if ( scalar(@svc_forward) == 1 ) {
  print $cgi->redirect(popurl(2). "view/svc_forward.cgi?". $svc_forward[0]->svcnum);
  #exit;
} elsif ( scalar(@svc_forward) == 0 ) {
%>
<!-- mason kludge -->
<%
  eidiot "No matching forwards found!\n";
} else {
%>
<!-- mason kludge -->
<%
  my $total = scalar(@svc_forward);
  print header("Mail forward Search Results",''), <<END;

    $total matching mail forwards found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #<BR><FONT SIZE=-1>(click to view forward)</FONT></TH>
        <TH>Mail to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
      </TR>
END

  foreach my $svc_forward (
    sort $sortby (@svc_forward)
  ) {
    my $svcnum = $svc_forward->svcnum;

    my $src = $svc_forward->src;
    $src = "<I>(anything)</I>$src" if $src =~ /^@/;
    if ( $svc_forward->srcsvc_acct ) {
      $src = qq!<A HREF="${p}view/svc_acct.cgi?!. $svc_forward->srcsvc. '">'.
             $svc_forward->srcsvc_acct->email. '</A>';
    }

    my $dst = $svc_forward->dst;
    if ( $svc_forward->dstsvc_acct ) {
      $dst = qq!<A HREF="${p}view/svc_acct.cgi?!. $svc_forward->dstsvc. '">'.
             $svc_forward->dstsvc_acct->email. '</A>';
    }

    print <<END;
      <TR>
        <TD><A HREF="${p}view/svc_forward.cgi?$svcnum">$svcnum</A></TD>
        <TD>$src</TD>
        <TD>$dst</TD>
      </TR>
END

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

%>
