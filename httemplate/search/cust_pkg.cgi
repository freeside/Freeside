<!-- $Id: cust_pkg.cgi,v 1.14 2002-02-09 18:24:02 ivan Exp $ -->
<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my %part_pkg = map { $_->pkgpart => $_ } qsearch('part_pkg', {});

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total;

my $unconf = '';
my($query) = $cgi->keywords;
my $sortby;
if ( $query eq 'pkgnum' ) {
  $sortby=\*pkgnum_sort;

} elsif ( $query eq 'APKG_pkgnum' ) {

  $sortby=\*pkgnum_sort;

  $unconf = "
    WHERE 0 <
      ( SELECT count(*) FROM pkg_svc
          WHERE pkg_svc.pkgpart = cust_pkg.pkgpart
            AND pkg_svc.quantity > ( SELECT count(*) FROM cust_svc
                                       WHERE cust_svc.pkgnum = cust_pkg.pkgnum
                                         AND cust_svc.svcpart = pkg_svc.svcpart
                                   )
      )
  ";

  #@cust_pkg=();
  ##perhaps this should go in cust_pkg as a qsearch-like constructor?
  #my($cust_pkg);
  #foreach $cust_pkg (
  #  qsearch('cust_pkg',{}, '', "ORDER BY pkgnum $limit" )
  #) {
  #  my($flag)=0;
  #  my($pkg_svc);
  #  PKG_SVC: 
  #  foreach $pkg_svc (qsearch('pkg_svc',{ 'pkgpart' => $cust_pkg->pkgpart })) {
  #    if ( $pkg_svc->quantity 
  #         > scalar(qsearch('cust_svc',{
  #             'pkgnum' => $cust_pkg->pkgnum,
  #             'svcpart' => $pkg_svc->svcpart,
  #           }))
  #       )
  #    {
  #      $flag=1;
  #      last PKG_SVC;
  #    }
  #  }
  #  push @cust_pkg, $cust_pkg if $flag;
  #}
  
} else {
  die "Empty QUERY_STRING!";
}

my $statement = "SELECT COUNT(*) FROM cust_pkg $unconf";
my $sth = dbh->prepare($statement)
  or die dbh->errstr. " doing $statement";
$sth->execute or die "Error executing \"$statement\": ". $sth->errstr;

$total = $sth->fetchrow_arrayref->[0];

my @cust_pkg = qsearch('cust_pkg',{}, '', "$unconf ORDER BY pkgnum $limit" );


if ( scalar(@cust_pkg) == 1 ) {
  my($pkgnum)=$cust_pkg[0]->pkgnum;
  print $cgi->redirect(popurl(2). "view/cust_pkg.cgi?$pkgnum");
  #exit;
} elsif ( scalar(@cust_pkg) == 0 ) { #error
  eidiot("No packages found");
} else {
  $total ||= scalar(@cust_pkg);

  #begin pager
  my $pager = '';
  if ( $total != scalar(@cust_pkg) && $maxrecords ) {
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
  
  print header('Package Search Results',''),
        "$total matching packages found<BR><BR>$pager", &table(), <<END;
      <TR>
        <TH>Package</TH>
        <TH><FONT SIZE=-1>Setup</FONT></TH>
        <TH><FONT SIZE=-1>Next<BR>bill</FONT></TH>
        <TH><FONT SIZE=-1>Susp.</FONT></TH>
        <TH><FONT SIZE=-1>Expire</FONT></TH>
        <TH><FONT SIZE=-1>Cancel</FONT></TH>
        <TH><FONT SIZE=-1>Cust#</FONT></TH>
        <TH>(bill) name</TH>
        <TH>company</TH>
END

if ( defined dbdef->table('cust_main')->column('ship_last') ) {
  print <<END;
      <TH>(service) name</TH>
      <TH>company</TH>
END
}

print <<END;
        <TH COLSPAN=2>Services</TH>
      </TR>
END

  my $n1 = '<TR>';
  my(%saw,$cust_pkg);
  foreach $cust_pkg (
    sort $sortby grep(!$saw{$_->pkgnum}++, @cust_pkg)
  ) {
    my($cust_main)=qsearchs('cust_main',{'custnum'=>$cust_pkg->custnum});
    my($pkgnum, $setup, $bill, $susp, $expire, $cancel,
       $custnum, $last, $first, $company ) = (
      $cust_pkg->pkgnum,
      $cust_pkg->getfield('setup')
        ? time2str("%D", $cust_pkg->getfield('setup') )
        : '',
      $cust_pkg->getfield('bill')
        ? time2str("%D", $cust_pkg->getfield('bill') )
        : '',
      $cust_pkg->getfield('susp')
        ? time2str("%D", $cust_pkg->getfield('susp') )
        : '',
      $cust_pkg->getfield('expire')
        ? time2str("%D", $cust_pkg->getfield('expire') )
        : '',
      $cust_pkg->getfield('cancel')
        ? time2str("%D", $cust_pkg->getfield('cancel') )
        : '',
      $cust_pkg->custnum,
      $cust_main ? $cust_main->last : '',
      $cust_main ? $cust_main->first : '',
      $cust_main ? $cust_main->company : '',
    );
    my($ship_last, $ship_first, $ship_company);
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      ($ship_last, $ship_first, $ship_company) = (
        $cust_main
          ? ( $cust_main->ship_last || $cust_main->getfield('last') )
          : '',
        $cust_main 
          ? ( $cust_main->ship_last
              ? $cust_main->ship_first
              : $cust_main->first )
          : '',
        $cust_main 
          ? ( $cust_main->ship_last
              ? $cust_main->ship_company
              : $cust_main->company )
          : '',
      );
    }
    my $pkg = $part_pkg{$cust_pkg->pkgpart}->pkg;
    #$pkg .= ' - '. $part_pkg{$cust_pkg->pkgpart}->comment;
    my @cust_svc = qsearch( 'cust_svc', { 'pkgnum' => $pkgnum } );
    my $rowspan = scalar(@cust_svc) || 1;
    my $p = popurl(2);
    print $n1, <<END;
      <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_pkg.cgi?$pkgnum"><FONT SIZE=-1>$pkgnum - $pkg</FONT></A></TD>
      <TD>$setup</TD>
      <TD>$bill</TD>
      <TD>$susp</TD>
      <TD>$expire</TD>
      <TD>$cancel</TD>
END
    if ( $cust_main ) {
      print <<END;
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$custnum</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$last, $first</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$company</A></FONT></TD>
END
      if ( defined dbdef->table('cust_main')->column('ship_last') ) {
        print <<END;
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$ship_last, $ship_first</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$ship_company</A></FONT></TD>
END
      }
    } else {
      my $colspan = defined dbdef->table('cust_main')->column('ship_last')
                    ? 5 : 3;
      print <<END;
      <TD ROWSPAN=$rowspan COLSPAN=$colspan>WARNING: couldn't find cust_main.custnum $custnum (cust_pkg.pkgnum $pkgnum)</TD>
END
    }

    my $n2 = '';
    foreach my $cust_svc ( @cust_svc ) {
      my($label, $value, $svcdb) = $cust_svc->label;
      my $svcnum = $cust_svc->svcnum;
      my $sview = $p. "view";
      print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
            qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
      $n2="</TR><TR>";
    }

    $n1 = "</TR><TR>";

  }
    print '</TR>';
 
  print "</TABLE>$pager</BODY></HTML>";

}

sub pkgnum_sort {
  $a->getfield('pkgnum') <=> $b->getfield('pkgnum');
}

%>
