<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

#my $cache;

#my $monsterjoin = <<END;
#cust_main left outer join (
#  ( cust_pkg left outer join part_pkg using(pkgpart)
#  ) left outer join (
#    (
#      (
#        ( cust_svc left outer join part_svc using (svcpart)
#        ) left outer join svc_acct using (svcnum)
#      ) left outer join svc_domain using(svcnum)
#    ) left outer join svc_forward using(svcnum)
#  ) using (pkgnum)
#) using (custnum)
#END

#my $monsterjoin = <<END;
#cust_main left outer join (
#  ( cust_pkg left outer join part_pkg using(pkgpart)
#  ) left outer join (
#    (
#      (
#        ( cust_svc left outer join part_svc using (svcpart)
#        ) left outer join (
#          svc_acct left outer join (
#            select svcnum, domain, catchall from svc_domain
#            ) as svc_acct_domsvc (
#              svc_acct_svcnum, svc_acct_domain, svc_acct_catchall
#          ) on svc_acct.domsvc = svc_acct_domsvc.svc_acct_svcnum
#        ) using (svcnum)
#      ) left outer join svc_domain using(svcnum)
#    ) left outer join svc_forward using(svcnum)
#  ) using (pkgnum)
#) using (custnum)
#END

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total = 0;

my(@cust_main, $sortby, $orderby);
if ( $cgi->param('browse')
     || $cgi->param('otaker_on')
) {

  my %search = ();
  if ( $cgi->param('browse') ) {
    my $query = $cgi->param('browse');
    if ( $query eq 'custnum' ) {
      $sortby=\*custnum_sort;
      $orderby = "ORDER BY custnum";
    } elsif ( $query eq 'last' ) {
      $sortby=\*last_sort;
      $orderby = "ORDER BY LOWER(last || ' ' || first)";
    } elsif ( $query eq 'company' ) {
      $sortby=\*company_sort;
      $orderby = "ORDER BY LOWER(company || ' ' || last || ' ' || first )";
    } else {
      die "unknown browse field $query";
    }
  } else {
    $sortby = \*last_sort; #??
    $orderby = "ORDER BY LOWER(last || ' ' || first)"; #??
    if ( $cgi->param('otaker_on') ) {
      $cgi->param('otaker') =~ /^(\w{1,32})$/ or eidiot "Illegal otaker\n";
      $search{otaker} = $1;
    } else {
      die "unknown query...";
    }
  }

  my $ncancelled = '';

  if ( driver_name eq 'mysql' ) {

       my $sql = "CREATE TEMPORARY TABLE temp1_$$ TYPE=MYISAM
                    SELECT cust_pkg.custnum,COUNT(*) as count
                      FROM cust_pkg,cust_main
                        WHERE cust_pkg.custnum = cust_main.custnum
                              AND ( cust_pkg.cancel IS NULL
                                    OR cust_pkg.cancel = 0 )
                        GROUP BY cust_pkg.custnum";
       my $sth = dbh->prepare($sql) or die dbh->errstr. " preparing $sql";
       $sth->execute or die "Error executing \"$sql\": ". $sth->errstr;
       $sql = "CREATE TEMPORARY TABLE temp2_$$ TYPE=MYISAM
                 SELECT cust_pkg.custnum,COUNT(*) as count
                   FROM cust_pkg,cust_main
                     WHERE cust_pkg.custnum = cust_main.custnum
                     GROUP BY cust_pkg.custnum";
       $sth = dbh->prepare($sql) or die dbh->errstr. " preparing $sql";
       $sth->execute or die "Error executing \"$sql\": ". $sth->errstr;
  }

  if (  $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
       || ( $conf->exists('hidecancelledcustomers')
             && ! $cgi->param('showcancelledcustomers') )
     ) {
    #grep { $_->ncancelled_pkgs || ! $_->all_pkgs }
    if ( driver_name eq 'mysql' ) {
       $ncancelled = "
          temp1_$$.custnum = cust_main.custnum
               AND temp2_$$.custnum = cust_main.custnum
               AND (temp1_$$.count > 0
                       OR temp2_$$.count = 0 )
       ";
    } else {
       $ncancelled = "
          0 < ( SELECT COUNT(*) FROM cust_pkg
                       WHERE cust_pkg.custnum = cust_main.custnum
                         AND ( cust_pkg.cancel IS NULL
                               OR cust_pkg.cancel = 0
                             )
                   )
            OR 0 = ( SELECT COUNT(*) FROM cust_pkg
                       WHERE cust_pkg.custnum = cust_main.custnum
                   )
       ";
    }

  }

  #EWWWWWW
  my $qual = join(' AND ',
            map { "$_ = ". dbh->quote($search{$_}) } keys %search );

  if ( $ncancelled ) {
    $qual .= ' AND ' if $qual;
    $qual .= $ncancelled;
  }
    
  $qual = " WHERE $qual" if $qual;
  my $statement;
  if ( driver_name eq 'mysql' ) {
    $statement = "SELECT COUNT(*) FROM cust_main";
    $statement .= ", temp1_$$, temp2_$$ $qual" if $qual;
  } else {
    $statement = "SELECT COUNT(*) FROM cust_main $qual";
  }
  my $sth = dbh->prepare($statement) or die dbh->errstr." preparing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;

  $total = $sth->fetchrow_arrayref->[0];

  if ( $ncancelled ) {
    if ( %search ) {
      $ncancelled = " AND $ncancelled";
    } else {
      $ncancelled = " WHERE $ncancelled";
    }
  }

  my @just_cust_main;
  if ( driver_name eq 'mysql' ) {
    @just_cust_main = qsearch('cust_main', \%search, 'cust_main.*',
                              ",temp1_$$,temp2_$$ $ncancelled $orderby $limit");
  } else {
    @just_cust_main = qsearch('cust_main', \%search, '',   
                              "$ncancelled $orderby $limit" );
  }
  if ( driver_name eq 'mysql' ) {
    my $sql = "DROP TABLE temp1_$$,temp2_$$;";
    my $sth = dbh->prepare($sql) or die dbh->errstr. " preparing $sql";
    $sth->execute or die "Error executing \"$sql\": ". $sth->errstr;
  }
  @cust_main = @just_cust_main;

#  foreach my $cust_main ( @just_cust_main ) {
#
#    my @one_cust_main;
#    $FS::Record::DEBUG=1;
#    ( $cache, @one_cust_main ) = jsearch(
#      "$monsterjoin",
#      { 'custnum' => $cust_main->custnum },
#      '',
#      '',
#      'cust_main',
#      'custnum',
#    );
#    push @cust_main, @one_cust_main;
#  }

} else {
  @cust_main=();
  $sortby = \*last_sort;

  push @cust_main, @{&custnumsearch}
    if $cgi->param('custnum_on') && $cgi->param('custnum_text');
  push @cust_main, @{&cardsearch}
    if $cgi->param('card_on') && $cgi->param('card');
  push @cust_main, @{&lastsearch}
    if $cgi->param('last_on') && $cgi->param('last_text');
  push @cust_main, @{&companysearch}
    if $cgi->param('company_on') && $cgi->param('company_text');
  push @cust_main, @{&address2search}
    if $cgi->param('address2_on') && $cgi->param('address2_text');
  push @cust_main, @{&phonesearch}
    if $cgi->param('phone_on') && $cgi->param('phone_text');
  push @cust_main, @{&referralsearch}
    if $cgi->param('referral_custnum');

  if ( $cgi->param('company_on') && $cgi->param('company_text') ) {
    $sortby = \*company_sort;
    push @cust_main, @{&companysearch};
  }

  @cust_main = grep { $_->ncancelled_pkgs || ! $_->all_pkgs } @cust_main
    if $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
       || ( $conf->exists('hidecancelledcustomers')
             && ! $cgi->param('showcancelledcustomers') );

  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;
}

my %all_pkgs;
if ( $conf->exists('hidecancelledpackages' ) ) {
  %all_pkgs = map { $_->custnum => [ $_->ncancelled_pkgs ] } @cust_main;
} else {
  %all_pkgs = map { $_->custnum => [ $_->all_pkgs ] } @cust_main;
}
#%all_pkgs = ();

if ( scalar(@cust_main) == 1 && ! $cgi->param('referral_custnum') ) {
  if ( $cgi->param('quickpay') eq 'yes' ) {
    print $cgi->redirect(popurl(2). "edit/cust_pay.cgi?quickpay=yes;custnum=". $cust_main[0]->custnum);
  } else {
    print $cgi->redirect(popurl(2). "view/cust_main.cgi?". $cust_main[0]->custnum);
  }
  #exit;
} elsif ( scalar(@cust_main) == 0 ) {
%>
<!-- mason kludge -->
<%
  eidiot "No matching customers found!\n";
} else { 
%>
<!-- mason kludge -->
<%

  $total ||= scalar(@cust_main);
  print header("Customer Search Results",menubar(
    'Main Menu', popurl(2)
  )), "$total matching customers found ";

  #begin pager
  my $pager = '';
  if ( $total != scalar(@cust_main) && $maxrecords ) {
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
  
  if ( $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
       || ( $conf->exists('hidecancelledcustomers')
            && ! $cgi->param('showcancelledcustomers')
          )
     ) {
    $cgi->param('showcancelledcustomers', 1);
    $cgi->param('offset', 0);
    print qq!( <a href="!. $cgi->self_url. qq!">show cancelled customers</a> )!;
  } else {
    $cgi->param('showcancelledcustomers', 0);
    $cgi->param('offset', 0);
    print qq!( <a href="!. $cgi->self_url. qq!">hide cancelled customers</a> )!;
  }
  if ( $cgi->param('referral_custnum') ) {
    $cgi->param('referral_custnum') =~ /^(\d+)$/
      or eidiot "Illegal referral_custnum\n";
    my $referral_custnum = $1;
    my $cust_main = qsearchs('cust_main', { custnum => $referral_custnum } );
    print '<FORM METHOD=POST>'.
          qq!<INPUT TYPE="hidden" NAME="referral_custnum" VALUE="$referral_custnum">!.
          'referrals of <A HREF="'. popurl(2).
          "view/cust_main.cgi?$referral_custnum\">$referral_custnum: ".
          ( $cust_main->company
            || $cust_main->last. ', '. $cust_main->first ).
          '</A>';
    print "\n",<<END;
      <SCRIPT>
      function changed(what) {
        what.form.submit();
      }
      </SCRIPT>
END
    print ' <SELECT NAME="referral_depth" SIZE="1" onChange="changed(this)">';
    my $max = 8; #config file
    $cgi->param('referral_depth') =~ /^(\d*)$/ 
      or eidiot "Illegal referral_depth";
    my $referral_depth = $1;

    foreach my $depth ( 1 .. $max ) {
      print '<OPTION',
            ' SELECTED'x($depth == $referral_depth),
            ">$depth";
    }
    print "</SELECT> levels deep".
          '<NOSCRIPT> <INPUT TYPE="submit" VALUE="change"></NOSCRIPT>'.
          '</FORM>';
  }

  print "<BR><BR>". $pager. &table(). <<END;
      <TR>
        <TH></TH>
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
        <TH>Packages</TH>
        <TH COLSPAN=2>Services</TH>
      </TR>
END

  my(%saw,$cust_main);
  my $p = popurl(2);
  foreach $cust_main (
    sort $sortby grep(!$saw{$_->custnum}++, @cust_main)
  ) {
    my($custnum,$last,$first,$company)=(
      $cust_main->custnum,
      $cust_main->getfield('last'),
      $cust_main->getfield('first'),
      $cust_main->company,
    );

    my(@lol_cust_svc);
    my($rowspan)=0;#scalar( @{$all_pkgs{$custnum}} );
    foreach ( @{$all_pkgs{$custnum}} ) {
      #my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
      my @cust_svc = $_->cust_svc;
      push @lol_cust_svc, \@cust_svc;
      $rowspan += scalar(@cust_svc) || 1;
    }

    #my($rowspan) = scalar(@{$all_pkgs{$custnum}});
    my $view;
    if ( defined $cgi->param('quickpay') && $cgi->param('quickpay') eq 'yes' ) {
      $view = $p. 'edit/cust_pay.cgi?quickpay=yes;custnum='. $custnum;
    } else {
      $view = $p. 'view/cust_main.cgi?'. $custnum;
    }
    my $pcompany = $company
      ? qq!<A HREF="$view"><FONT SIZE=-1>$company</FONT></A>!
      : '<FONT SIZE=-1>&nbsp;</FONT>';
    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$custnum</FONT></A></TD>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$last, $first</FONT></A></TD>
      <TD ROWSPAN=$rowspan>$pcompany</TD>
END
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      my($ship_last,$ship_first,$ship_company)=(
        $cust_main->ship_last || $cust_main->getfield('last'),
        $cust_main->ship_last ? $cust_main->ship_first : $cust_main->first,
        $cust_main->ship_last ? $cust_main->ship_company : $cust_main->company,
      );
      my $pship_company = $ship_company
        ? qq!<A HREF="$view"><FONT SIZE=-1>$ship_company</FONT></A>!
        : '<FONT SIZE=-1>&nbsp;</FONT>';
      print <<END;
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$ship_last, $ship_first</FONT></A></TD>
      <TD ROWSPAN=$rowspan>$pship_company</A></TD>
END
    }

    my($n1)='';
    foreach ( @{$all_pkgs{$custnum}} ) {
      my $pkgnum = $_->pkgnum;
#      my $part_pkg = qsearchs( 'part_pkg', { pkgpart => $_->pkgpart } );
      my $part_pkg = $_->part_pkg;

      my $pkg = $part_pkg->pkg;
      my $comment = $part_pkg->comment;
      my $pkgview = $p. 'view/cust_pkg.cgi?'. $pkgnum;
      my @cust_svc = @{shift @lol_cust_svc};
      #my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
      my $rowspan = scalar(@cust_svc) || 1;

      print $n1, qq!<TD ROWSPAN=$rowspan><A HREF="$pkgview"><FONT SIZE=-1>$pkg - $comment</FONT></A></TD>!;
      my($n2)='';
      foreach my $cust_svc ( @cust_svc ) {
         my($label, $value, $svcdb) = $cust_svc->label;
         my($svcnum) = $cust_svc->svcnum;
         my($sview) = $p.'view';
         print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
               qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
         $n2="</TR><TR>";
      }
      #print qq!</TR><TR>\n!;
      $n1="</TR><TR>";
    }
    print "</TR>";
  }
 
  print "</TABLE>$pager</BODY></HTML>";

}

#undef $cache; #does this help?

#

sub last_sort {
  lc($a->getfield('last')) cmp lc($b->getfield('last'))
  || lc($a->first) cmp lc($b->first);
}

sub company_sort {
  return -1 if $a->company && ! $b->company;
  return 1 if ! $a->company && $b->company;
  lc($a->company) cmp lc($b->company)
  || lc($a->getfield('last')) cmp lc($b->getfield('last'))
  || lc($a->first) cmp lc($b->first);;
}

sub custnum_sort {
  $a->getfield('custnum') <=> $b->getfield('custnum');
}

sub custnumsearch {

  my $custnum = $cgi->param('custnum_text');
  $custnum =~ s/\D//g;
  $custnum =~ /^(\d{1,23})$/ or eidiot "Illegal customer number\n";
  $custnum = $1;
  
  [ qsearchs('cust_main', { 'custnum' => $custnum } ) ];
}

sub cardsearch {

  my($card)=$cgi->param('card');
  $card =~ s/\D//g;
  $card =~ /^(\d{13,16})$/ or eidiot "Illegal card number\n";
  my($payinfo)=$1;

  [ qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'CARD'}) ];
}

sub referralsearch {
  $cgi->param('referral_custnum') =~ /^(\d+)$/
    or eidiot "Illegal referral_custnum";
  my $cust_main = qsearchs('cust_main', { 'custnum' => $1 } )
    or eidiot "Customer $1 not found";
  my $depth;
  if ( $cgi->param('referral_depth') ) {
    $cgi->param('referral_depth') =~ /^(\d+)$/
      or eidiot "Illegal referral_depth";
    $depth = $1;
  } else {
    $depth = 1;
  }
  [ $cust_main->referral_cust_main($depth) ];
}

sub lastsearch {
  my(%last_type);
  my @cust_main;
  foreach ( $cgi->param('last_type') ) {
    $last_type{$_}++;
  }

  $cgi->param('last_text') =~ /^([\w \,\.\-\']*)$/
    or eidiot "Illegal last name";
  my($last)=$1;

  if ( $last_type{'Exact'} || $last_type{'Fuzzy'} ) {
    push @cust_main, qsearch( 'cust_main',
                              { 'last' => { 'op'    => 'ILIKE',
                                            'value' => $last    } } );

    push @cust_main, qsearch( 'cust_main',
                              { 'ship_last' => { 'op'    => 'ILIKE',
                                                 'value' => $last    } } )
      if defined dbdef->table('cust_main')->column('ship_last');
  }

  if ( $last_type{'Substring'} || $last_type{'All'} ) {

    push @cust_main, qsearch( 'cust_main',
                              { 'last' => { 'op'    => 'ILIKE',
                                            'value' => "%$last%" } } );

    push @cust_main, qsearch( 'cust_main',
                              { 'ship_last' => { 'op'    => 'ILIKE',
                                                 'value' => "%$last%" } } )
      if defined dbdef->table('cust_main')->column('ship_last');

  }

  if ( $last_type{'Fuzzy'} || $last_type{'All'} ) {

    &FS::cust_main::check_and_rebuild_fuzzyfiles;
    my $all_last = &FS::cust_main::all_last;

    my %last;
    if ( $last_type{'Fuzzy'} || $last_type{'All'} ) { 
      foreach ( amatch($last, [ qw(i) ], @$all_last) ) {
        $last{$_}++; 
      }
    }

    #if ($last_type{'Sound-alike'}) {
    #}

    foreach ( keys %last ) {
      push @cust_main, qsearch('cust_main',{'last'=>$_});
      push @cust_main, qsearch('cust_main',{'ship_last'=>$_})
        if defined dbdef->table('cust_main')->column('ship_last');
    }

  }

  \@cust_main;
}

sub companysearch {

  my(%company_type);
  my @cust_main;
  foreach ( $cgi->param('company_type') ) {
    $company_type{$_}++ 
  };

  $cgi->param('company_text') =~
    /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
      or eidiot "Illegal company";
  my $company = $1;

  if ( $company_type{'Exact'} || $company_type{'Fuzzy'} ) {
    push @cust_main, qsearch( 'cust_main',
                              { 'company' => { 'op'    => 'ILIKE',
                                               'value' => $company } } );

    push @cust_main, qsearch( 'cust_main',
                              { 'ship_company' => { 'op'    => 'ILIKE',
                                                    'value' => $company } } )
      if defined dbdef->table('cust_main')->column('ship_last');
  }

  if ( $company_type{'Substring'} || $company_type{'All'} ) {

    push @cust_main, qsearch( 'cust_main',
                              { 'company' => { 'op'    => 'ILIKE',
                                               'value' => "%$company%" } } );

    push @cust_main, qsearch( 'cust_main',
                              { 'ship_company' => { 'op'    => 'ILIKE',
                                                    'value' => "%$company%" } })
      if defined dbdef->table('cust_main')->column('ship_last');

  }

  if ( $company_type{'Fuzzy'} || $company_type{'All'} ) {

    &FS::cust_main::check_and_rebuild_fuzzyfiles;
    my $all_company = &FS::cust_main::all_company;

    my %company;
    if ( $company_type{'Fuzzy'} || $company_type{'All'} ) { 
      foreach ( amatch($company, [ qw(i) ], @$all_company ) ) {
        $company{$_}++;
      }
    }

    #if ($company_type{'Sound-alike'}) {
    #}

    foreach ( keys %company ) {
      push @cust_main, qsearch('cust_main',{'company'=>$_});
      push @cust_main, qsearch('cust_main',{'ship_company'=>$_})
        if defined dbdef->table('cust_main')->column('ship_last');
    }

  }

  \@cust_main;
}

sub address2search {
  my @cust_main;

  $cgi->param('address2_text') =~
    /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
      or eidiot "Illegal address2";
  my $address2 = $1;

  push @cust_main, qsearch( 'cust_main',
                            { 'address2' => { 'op'    => 'ILIKE',
                                              'value' => $address2 } } );
  push @cust_main, qsearch( 'cust_main',
                            { 'address2' => { 'op'    => 'ILIKE',
                                              'value' => $address2 } } )
    if defined dbdef->table('cust_main')->column('ship_last');

  \@cust_main;
}

sub phonesearch {
  my @cust_main;

  my $phone = $cgi->param('phone_text');

  #false laziness with Record::ut_phonen, only works with US/CA numbers...
  $phone =~ s/\D//g;
  $phone =~ /^(\d{3})(\d{3})(\d{4})(\d*)$/
    or eidiot gettext('illegal_phone'). ": $phone";
  $phone = "$1-$2-$3";
  $phone .= " x$4" if $4;

  my @fields = qw(daytime night fax);
  push @fields, qw(ship_daytime ship_night ship_fax)
    if defined dbdef->table('cust_main')->column('ship_last');

  for my $field ( @fields ) {
    push @cust_main, qsearch ( 'cust_main', 
                               { $field => { 'op'    => 'LIKE',
                                             'value' => "$phone%" } } );
  }

  \@cust_main;
}

%>
