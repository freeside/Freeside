<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my $orderby = ''; #removeme

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total;

my($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors

my $unlinked = '';
if ( $query =~ /^UN_(.*)$/ ) {
  $query = $1;
  my $empty = driver_name eq 'Pg' ? qq('') : qq("");
  if ( driver_name eq 'mysql' ) {
    $unlinked = "LEFT JOIN cust_svc ON cust_svc.svcnum = svc_acct.svcnum
                 WHERE cust_svc.pkgnum IS NULL
                    OR cust_svc.pkgnum = 0
                    OR cust_svc.pkgnum = $empty";
  } else {
    $unlinked = "
      WHERE 0 <
        ( SELECT count(*) FROM cust_svc
            WHERE cust_svc.svcnum = svc_acct.svcnum
              AND ( pkgnum IS NULL OR pkgnum = 0 )
        )
    ";
  }
}

my $tblname = driver_name eq 'mysql' ? 'svc_acct.' : '';
my(@svc_acct, $sortby);
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  $orderby = "ORDER BY ${tblname}svcnum";
} elsif ( $query eq 'username' ) {
  $sortby=\*username_sort;
  $orderby = "ORDER BY ${tblname}username";
} elsif ( $query eq 'uid' ) {
  $sortby=\*uid_sort;
  $orderby = ( $unlinked ? ' AND' : ' WHERE' ).
             " ${tblname}uid IS NOT NULL ORDER BY ${tblname}uid";
} elsif ( $cgi->param('popnum') =~ /^(\d+)$/ ) {
  $unlinked .= ( $unlinked ? 'AND' : 'WHERE' ).
               " popnum = $1";
  $sortby=\*username_sort;
  $orderby = "ORDER BY ${tblname}username";
} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  $unlinked .= ( $unlinked ? ' AND' : ' WHERE' ).
               " $1 = ( SELECT svcpart FROM cust_svc ".
               "        WHERE cust_svc.svcnum = svc_acct.svcnum ) ";
  $sortby=\*uid_sort;
  #$sortby=\*svcnum_sort;
} else {
  $sortby=\*uid_sort;
  @svc_acct = @{&usernamesearch};
}


if (    $query eq 'svcnum'
     || $query eq 'username'
     || $query eq 'uid'
     || $cgi->param('popnum') =~ /^(\d+)$/
     || $cgi->param('svcpart') =~ /^(\d+)$/
   ) {

  my $statement = "SELECT COUNT(*) FROM svc_acct $unlinked";
  my $sth = dbh->prepare($statement)
    or die dbh->errstr. " doing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;

  $total = $sth->fetchrow_arrayref->[0];

  @svc_acct = qsearch('svc_acct', {}, '', "$unlinked $orderby $limit");

}

if ( scalar(@svc_acct) == 1 ) {
  my($svcnum)=$svc_acct[0]->svcnum;
  print $cgi->redirect(popurl(2). "view/svc_acct.cgi?$svcnum");  #redirect
  #exit;
} elsif ( scalar(@svc_acct) == 0 ) { #error
%>
<!-- mason kludge -->
<%
  idiot("Account not found");
} else {
%>
<!-- mason kludge -->
<%
  $total ||= scalar(@svc_acct);

  #begin pager
  my $pager = '';
  if ( $total != scalar(@svc_acct) && $maxrecords ) {
    unless ( $offset == 0 ) {
      $cgi->param('offset', $offset - $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Previous</FONT></B></A> ';
    }
    my $poff;
    my $page;
    for ( $poff = 0; $poff < $total; $poff += $maxrecords ) {
      $page++;
      if ( $offset == $poff ) {
        $pager .= qq!<FONT SIZE="+2">$page</FONT> !;
      } else {
        $cgi->param('offset', $poff);
        $pager .= qq!<A HREF="!. $cgi->self_url. qq!">$page</A> !;
      }
    }
    unless ( $offset + $maxrecords > $total ) {
      $cgi->param('offset', $offset + $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Next</FONT></B></A> ';
    }
  }
  #end pager

  print header("Account Search Results",menubar('Main Menu'=>popurl(2))),
        "$total matching accounts found<BR><BR>$pager",
        &table(), <<END;
      <TR>
        <TH><FONT SIZE=-1>#</FONT></TH>
        <TH><FONT SIZE=-1>Username</FONT></TH>
        <TH><FONT SIZE=-1>Domain</FONT></TH>
        <TH><FONT SIZE=-1>UID</FONT></TH>
        <TH><FONT SIZE=-1>Service</FONT></TH>
        <TH><FONT SIZE=-1>Cust#</FONT></TH>
        <TH><FONT SIZE=-1>(bill) name</FONT></TH>
        <TH><FONT SIZE=-1>company</FONT></TH>
END
  if ( defined dbdef->table('cust_main')->column('ship_last') ) {
    print <<END;
        <TH><FONT SIZE=-1>(service) name</FONT></TH>
        <TH><FONT SIZE=-1>company</FONT></TH>
END
  }
  print "</TR>";

  my(%saw,$svc_acct);
  my $p = popurl(2);
  foreach $svc_acct (
    sort $sortby grep(!$saw{$_->svcnum}++, @svc_acct)
  ) {
    my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $svc_acct->svcnum })
      or die "No cust_svc record for svcnum ". $svc_acct->svcnum;
    my $part_svc = qsearchs('part_svc', { 'svcpart' => $cust_svc->svcpart })
      or die "No part_svc record for svcpart ". $cust_svc->svcpart;

    my $domain;
    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc });
    if ( $svc_domain ) {
      $domain = "<A HREF=\"${p}view/svc_domain.cgi?". $svc_domain->svcnum.
                "\">". $svc_domain->domain. "</A>";
    } else {
      die "No svc_domain.svcnum record for svc_acct.domsvc: ".
          $svc_acct->domsvc;
    }
    my($cust_pkg,$cust_main);
    if ( $cust_svc->pkgnum ) {
      $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $cust_svc->pkgnum })
        or die "No cust_pkg record for pkgnum ". $cust_svc->pkgnum;
      $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pkg->custnum })
        or die "No cust_main record for custnum ". $cust_pkg->custnum;
    }
    my($svcnum, $username, $uid, $svc, $custnum, $last, $first, $company) = (
      $svc_acct->svcnum,
      $svc_acct->getfield('username'),
      $svc_acct->getfield('uid'),
      $part_svc->svc,
      $cust_svc->pkgnum ? $cust_main->custnum : '',
      $cust_svc->pkgnum ? $cust_main->getfield('last') : '',
      $cust_svc->pkgnum ? $cust_main->getfield('first') : '',
      $cust_svc->pkgnum ? $cust_main->company : '',
    );
    my($pcustnum) = $custnum
      ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\"><FONT SIZE=-1>$custnum</FONT></A>"
      : "<I>(unlinked)</I>"
    ;
    my $pname = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$last, $first</A>" : '';
    my $pcompany = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$company</A>" : '';
    my($pship_name, $pship_company);
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      my($ship_last, $ship_first, $ship_company) = (
        $cust_svc->pkgnum ? ( $cust_main->ship_last || $last ) : '',
        $cust_svc->pkgnum ? ( $cust_main->ship_last
                              ? $cust_main->ship_first
                              : $first
                            ) : '',
        $cust_svc->pkgnum ? ( $cust_main->ship_last
                              ? $cust_main->ship_company
                              : $company
                            ) : '',
      );
      $pship_name = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$ship_last, $ship_first</A>" : '';
      $pship_company = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$ship_company</A>" : '';
    }
    print <<END;
    <TR>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$svcnum</FONT></A></TD>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$username</FONT></A></TD>
      <TD><FONT SIZE=-1>$domain</FONT></TD>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$uid</FONT></A></TD>
      <TD><FONT SIZE=-1>$svc</FONT></TH>
      <TD><FONT SIZE=-1>$pcustnum</FONT></TH>
      <TD><FONT SIZE=-1>$pname<FONT></TH>
      <TD><FONT SIZE=-1>$pcompany</FONT></TH>
END
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      print <<END;
      <TD><FONT SIZE=-1>$pship_name<FONT></TH>
      <TD><FONT SIZE=-1>$pship_company</FONT></TH>
END
    }
    print "</TR>";

  }
 
  print "</TABLE>$pager<BR>".
        '</BODY></HTML>';

}

sub svcnum_sort {
  $a->getfield('svcnum') <=> $b->getfield('svcnum');
}

sub username_sort {
  $a->getfield('username') cmp $b->getfield('username');
}

sub uid_sort {
  $a->getfield('uid') <=> $b->getfield('uid');
}

sub usernamesearch {

  my @svc_acct;

  my %username_type;
  foreach ( $cgi->param('username_type') ) {
    $username_type{$_}++;
  }

  $cgi->param('username') =~ /^([\w\-\.\&]+)$/; #untaint username_text
  my $username = $1;

  if ( $username_type{'Exact'} || $username_type{'Fuzzy'} ) {
    push @svc_acct, qsearch( 'svc_acct',
                             { 'username' => { 'op'    => 'ILIKE',
                                               'value' => $username } } );
  }

  if ( $username_type{'Substring'} || $username_type{'All'} ) {
    push @svc_acct, qsearch( 'svc_acct',
                             { 'username' => { 'op'    => 'ILIKE',
                                               'value' => "%$username%" } } );
  }

  if ( $username_type{'Fuzzy'} || $username_type{'All'} ) {
    &FS::svc_acct::check_and_rebuild_fuzzyfiles;
    my $all_username = &FS::svc_acct::all_username;

    my %username;
    if ( $username_type{'Fuzzy'} || $username_type{'All'} ) { 
      foreach ( amatch($username, [ qw(i) ], @$all_username) ) {
        $username{$_}++; 
      }
    }

    #if ($username_type{'Sound-alike'}) {
    #}

    foreach ( keys %username ) {
      push @svc_acct, qsearch('svc_acct',{'username'=>$_});
    }

  }

  #[ qsearch('svc_acct',{'username'=>$username}) ];
  \@svc_acct;

}

%>
