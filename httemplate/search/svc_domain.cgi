<%

my $conf = new FS::Conf;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
my(@svc_domain,$sortby);
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'domain' ) {
  $sortby=\*domain_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'UN_svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} elsif ( $query eq 'UN_domain' ) {
  $sortby=\*domain_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  @svc_domain =
    qsearch( 'svc_domain', {}, '',
               " WHERE $1 = ( SELECT svcpart FROM cust_svc ".
               "              WHERE cust_svc.svcnum = svc_domain.svcnum ) "
    );
  $sortby=\*svcnum_sort;
} else {
  $cgi->param('domain') =~ /^([\w\-\.]+)$/; 
  my($domain)=$1;
  #push @svc_domain, qsearchs('svc_domain',{'domain'=>$domain});
  @svc_domain = qsearchs('svc_domain',{'domain'=>$domain});
}

if ( scalar(@svc_domain) == 1 ) {
  print $cgi->redirect(popurl(2). "view/svc_domain.cgi?". $svc_domain[0]->svcnum);
  #exit;
} elsif ( scalar(@svc_domain) == 0 ) {
%>
<!-- mason kludge -->
<%
  eidiot "No matching domains found!\n";
} else {
%>
<!-- mason kludge -->
<%
  my($total)=scalar(@svc_domain);
  print header("Domain Search Results",''), <<END;

    $total matching domains found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH>Domain</TH>
<!--        <TH>Mail to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
-->
      </TR>
END

#  my(%saw);                 # if we've multiple domains with the same
                             # svcnum, then we've a corrupt database

  foreach my $svc_domain (
#    sort $sortby grep(!$saw{$_->svcnum}++, @svc_domain)
    sort $sortby (@svc_domain)
  ) {
    my($svcnum,$domain)=(
      $svc_domain->svcnum,
      $svc_domain->domain,
    );

    #don't display all accounts here
    my $rowspan = 1;

    #my @svc_acct=qsearch('svc_acct',{'domsvc' => $svcnum});
    #my $rowspan = 0;
    #
    #my $n1 = '';
    #my($svc_acct, @rows);
    #foreach $svc_acct (
    #  sort {$b->getfield('username') cmp $a->getfield('username')} (@svc_acct)
    #) {
    #
    #  my (@forwards) = ();
    #
    #  my($svcnum,$username)=(
    #    $svc_acct->svcnum,
    #    $svc_acct->username,
    #  );
    #
    #  my @svc_forward = qsearch( 'svc_forward', { 'srcsvc' => $svcnum } );
    #  my $svc_forward;
    #  foreach $svc_forward (@svc_forward) {
    #    my($dstsvc,$dst) = (
    #      $svc_forward->dstsvc,
    #      $svc_forward->dst,
    #    );
    #    if ($dstsvc) {
    #      my $dst_svc_acct=qsearchs( 'svc_acct', { 'svcnum' => $dstsvc } );
    #      my $destination=$dst_svc_acct->email;
    #      push @forwards, qq!<TD><A HREF="!, popurl(2),
    #            qq!view/svc_acct.cgi?$dstsvc">$destination</A>!,
    #            qq!</TD></TR>!
    #      ;
    #    }else{
    #      push @forwards, qq!<TD>$dst</TD></TR>!
    #      ;
    #    }
    #  }
    #
    #  push @rows, qq!$n1<TD ROWSPAN=!, (scalar(@svc_forward) || 1),
    #        qq!><A HREF="!. popurl(2). qq!view/svc_acct.cgi?$svcnum">!,
    #  #print '', ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser );
    #        ( ($username eq '*') ? "<I>(anything)</I>" : $username ),
    #        qq!\@$domain</A> </TD>!,
    #  ;
    #
    #  push @rows, @forwards;
    #
    #  $rowspan += (scalar(@svc_forward) || 1);
    #  $n1 = "</TR><TR>";
    #}
    ##end of false laziness
    #
    #

    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_domain.cgi?$svcnum">$svcnum</A></TD>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_domain.cgi?$svcnum">$domain</A></TD>
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

sub domain_sort {
  $a->getfield('domain') cmp $b->getfield('domain');
}


%>
