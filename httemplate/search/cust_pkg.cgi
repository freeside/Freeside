<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my %part_pkg = map { $_->pkgpart => $_ } qsearch('part_pkg', {});

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total;

my($query) = $cgi->keywords;
my $sortby;
my @cust_pkg;

if ( $cgi->param('magic') && $cgi->param('magic') eq 'bill' ) {
  $sortby=\*bill_sort;
  my $range = '';
  if ( $cgi->param('beginning')
       && $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/ ) {
    my $beginning = str2time($1);
    $range = " WHERE bill >= $beginning ";
  }
  if ( $cgi->param('ending')
            && $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/ ) {
    my $ending = str2time($1) + 86400;
    $range .= ( $range ? ' AND ' : ' WHERE ' ). " bill <= $ending ";
  }

  #false laziness with below
  my $statement = "SELECT COUNT(*) FROM cust_pkg $range";
  warn $statement;
  my $sth = dbh->prepare($statement) or die dbh->errstr." preparing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;
  
  $total = $sth->fetchrow_arrayref->[0];
  
  @cust_pkg = qsearch('cust_pkg',{}, '', " $range ORDER BY bill $limit" );

} else {

  my $qual = '';
  if ( $query eq 'pkgnum' ) {
    $sortby=\*pkgnum_sort;

  } elsif ( $query eq 'SUSP_pkgnum' ) {

    $sortby=\*pkgnum_sort;

    $qual = 'WHERE susp IS NOT NULL AND susp != 0';

  } elsif ( $query eq 'APKG_pkgnum' ) {
  
    $sortby=\*pkgnum_sort;
  
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

    if ( driver_name eq 'mysql' ) {
      #$query = "DROP TABLE temp1_$$,temp2_$$;";
      #my $sth = dbh->prepare($query);
      #$sth->execute;

      $query = "CREATE TEMPORARY TABLE temp1_$$ TYPE=MYISAM
                  SELECT cust_svc.pkgnum,cust_svc.svcpart,COUNT(*) as count
                    FROM cust_pkg,cust_svc,pkg_svc
                      WHERE cust_pkg.pkgnum = cust_svc.pkgnum
                      AND cust_svc.svcpart = pkg_svc.svcpart
                      AND cust_pkg.pkgpart = pkg_svc.pkgpart
                      GROUP BY cust_svc.pkgnum,cust_svc.svcpart";
      $sth = dbh->prepare($query) or die dbh->errstr. " preparing $query";
         
      $sth->execute or die "Error executing \"$query\": ". $sth->errstr;
  
      $query = "CREATE TEMPORARY TABLE temp2_$$ TYPE=MYISAM
                  SELECT cust_pkg.pkgnum FROM cust_pkg
                    LEFT JOIN pkg_svc ON (cust_pkg.pkgpart=pkg_svc.pkgpart)
                    LEFT JOIN temp1_$$ ON (cust_pkg.pkgnum = temp1_$$.pkgnum
                                           AND pkg_svc.svcpart=temp1_$$.svcpart)
                    WHERE ( pkg_svc.quantity > temp1_$$.count
                            OR temp1_$$.pkgnum IS NULL )
                          AND pkg_svc.quantity != 0;";
      $sth = dbh->prepare($query) or die dbh->errstr. " preparing $query";   
      $sth->execute or die "Error executing \"$query\": ". $sth->errstr;
      $qual = " LEFT JOIN temp2_$$ ON cust_pkg.pkgnum = temp2_$$.pkgnum
                  WHERE temp2_$$.pkgnum IS NOT NULL";

    } else {

     $qual = "
       WHERE 0 <
         ( SELECT count(*) FROM pkg_svc
             WHERE pkg_svc.pkgpart = cust_pkg.pkgpart
               AND pkg_svc.quantity > ( SELECT count(*) FROM cust_svc
                                        WHERE cust_svc.pkgnum = cust_pkg.pkgnum
                                          AND cust_svc.svcpart = pkg_svc.svcpart
                                      )
         )
     ";

    }
    
  } else {
    die "Empty or unknown QUERY_STRING!";
  }
  
  my $statement = "SELECT COUNT(*) FROM cust_pkg $qual";
  my $sth = dbh->prepare($statement) or die dbh->errstr." preparing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;
  
  $total = $sth->fetchrow_arrayref->[0];

  my $tblname = driver_name eq 'mysql' ? 'cust_pkg.' : '';
  @cust_pkg =
    qsearch('cust_pkg',{}, '', "$qual ORDER BY ${tblname}pkgnum $limit" );

  if ( driver_name eq 'mysql' ) {
    $query = "DROP TABLE temp1_$$,temp2_$$;";
    my $sth = dbh->prepare($query) or die dbh->errstr. " doing $query";
    $sth->execute; # or die "Error executing \"$query\": ". $sth->errstr;
  }
  
}

if ( scalar(@cust_pkg) == 1 ) {
  my($pkgnum)=$cust_pkg[0]->pkgnum;
  print $cgi->redirect(popurl(2). "view/cust_pkg.cgi?$pkgnum");
  #exit;
} elsif ( scalar(@cust_pkg) == 0 ) { #error
%>
<!-- mason kludge -->
<%
  eidiot("No packages found");
} else {
%>
<!-- mason kludge -->
<%
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
      <TD ROWSPAN=$rowspan>$setup</TD>
      <TD ROWSPAN=$rowspan>$bill</TD>
      <TD ROWSPAN=$rowspan>$susp</TD>
      <TD ROWSPAN=$rowspan>$expire</TD>
      <TD ROWSPAN=$rowspan>$cancel</TD>
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

sub bill_sort {
  $a->getfield('bill') <=> $b->getfield('bill');
}

%>
