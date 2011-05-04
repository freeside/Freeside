%my $curuser = $FS::CurrentUser::CurrentUser;
%
%die "access denied"
%  unless $curuser->access_right('List customers');
%
%my $conf = new FS::Conf;
%my $maxrecords = $conf->config('maxsearchrecordsperpage');
%
%#my $cache;
%
%#my $monsterjoin = <<END;
%#cust_main left outer join (
%#  ( cust_pkg left outer join part_pkg using(pkgpart)
%#  ) left outer join (
%#    (
%#      (
%#        ( cust_svc left outer join part_svc using (svcpart)
%#        ) left outer join svc_acct using (svcnum)
%#      ) left outer join svc_domain using(svcnum)
%#    ) left outer join svc_forward using(svcnum)
%#  ) using (pkgnum)
%#) using (custnum)
%#END
%
%#my $monsterjoin = <<END;
%#cust_main left outer join (
%#  ( cust_pkg left outer join part_pkg using(pkgpart)
%#  ) left outer join (
%#    (
%#      (
%#        ( cust_svc left outer join part_svc using (svcpart)
%#        ) left outer join (
%#          svc_acct left outer join (
%#            select svcnum, domain, catchall from svc_domain
%#            ) as svc_acct_domsvc (
%#              svc_acct_svcnum, svc_acct_domain, svc_acct_catchall
%#          ) on svc_acct.domsvc = svc_acct_domsvc.svc_acct_svcnum
%#        ) using (svcnum)
%#      ) left outer join svc_domain using(svcnum)
%#    ) left outer join svc_forward using(svcnum)
%#  ) using (pkgnum)
%#) using (custnum)
%#END
%
%my $limit = '';
%$limit .= "LIMIT $maxrecords" if $maxrecords;
%
%my $offset = $cgi->param('offset') || 0;
%$limit .= " OFFSET $offset" if $offset;
%
%my $total = 0;
%
%my(@cust_main, $sortby, $orderby);
%my @select = ();
%my @addl_headers = ();
%my @addl_cols = ();
%if ( $cgi->param('browse')
%     || $cgi->param('otaker_on')
%     || $cgi->param('agentnum_on')
%) {
%
%  my %search = ();
%
%  if ( $cgi->param('browse') ) {
%    my $query = $cgi->param('browse');
%    if ( $query eq 'custnum' ) {
%      if ( $conf->exists('cust_main-default_agent_custid') ) {
%        $sortby=\*display_custnum_sort;
%        $orderby = "ORDER BY CASE WHEN agent_custid IS NOT NULL AND agent_custid != '' THEN CAST(agent_custid AS BIGINT) ELSE custnum END";
%      } else {
%        $sortby=\*custnum_sort;
%        $orderby = "ORDER BY custnum";
%      }
%    } elsif ( $query eq 'last' ) {
%      $sortby=\*last_sort;
%      $orderby = "ORDER BY LOWER(last || ' ' || first)";
%    } elsif ( $query eq 'company' ) {
%      $sortby=\*company_sort;
%      $orderby = "ORDER BY LOWER(company || ' ' || last || ' ' || first )";
%    } elsif ( $query eq 'tickets' ) {
%      $sortby = \*tickets_sort;
%      $orderby = "ORDER BY tickets DESC";
%      push @select, FS::TicketSystem->sql_num_customer_tickets. " as tickets";
%      push @addl_headers, 'Tickets';
%      push @addl_cols, 'tickets';
%    } elsif ( $query eq 'uspsunvalid' ) {
%       $search{'country'} = 'US';
%       $sortby=\*custnum_sort;
%       $orderby = "ORDER BY custnum";
%    } else {
%      die "unknown browse field $query";
%    }
%  } else {
%    $sortby = \*last_sort; #??
%    $orderby = "ORDER BY LOWER(last || ' ' || first)"; #??
%  }
%
%  if ( $cgi->param('otaker_on') ) {
%    die "access denied"
%      unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
%    $cgi->param('otaker') =~ /^(\w{1,32})$/ or errorpage("Illegal otaker");
%    $search{otaker} = $1;
%  } elsif ( $cgi->param('agentnum_on') ) {
%    $cgi->param('agentnum') =~ /^(\d+)$/ or errorpage("Illegal agentnum");
%    $search{agentnum} = $1;
%#  } else {
%#    die "unknown query...";
%  }
%
%  my @qual = ();
%
%  my $ncancelled = '';
%
%  if (  $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
%       || ( $conf->exists('hidecancelledcustomers')
%             && ! $cgi->param('showcancelledcustomers') )
%     ) {
%    #grep { $_->ncancelled_pkgs || ! $_->all_pkgs }
%    push @qual, FS::cust_main->uncancel_sql;
%
%   }
%
%  push @qual, FS::cust_main->cancel_sql   if $cgi->param('cancelled');
%  push @qual, FS::cust_main->prospect_sql if $cgi->param('prospect');
%  push @qual, FS::cust_main->active_sql   if $cgi->param('active');
%  push @qual, FS::cust_main->inactive_sql if $cgi->param('inactive');
%  push @qual, FS::cust_main->susp_sql     if $cgi->param('suspended');
%
%  #EWWWWWW
%  my $qual = join(' AND ',
%            map { "$_ = ". dbh->quote($search{$_}) } keys %search );
%
%  my $addl_qual = join(' AND ', @qual);
%
%  #here is the agent virtualization
%  $addl_qual .= ( $addl_qual ? ' AND ' : '' ).
%                $FS::CurrentUser::CurrentUser->agentnums_sql;
%
%  if ( $cgi->param('browse') && $cgi->param('browse') eq 'uspsunvalid' ) {
%       $addl_qual .= ' AND ( length(zip) < 9 OR upper(address1) != address1 OR upper(city) != city ) ';
%  }
%
%  if ( $addl_qual ) {
%    $qual .= ' AND ' if $qual;
%    $qual .= $addl_qual;
%  }
%    
%  $qual = " WHERE $qual" if $qual;
%  my $statement = "SELECT COUNT(*) FROM cust_main $qual";
%  my $sth = dbh->prepare($statement) or die dbh->errstr." preparing $statement";
%  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;
%
%  $total = $sth->fetchrow_arrayref->[0];
%
%  if ( $addl_qual ) {
%    if ( %search ) {
%      $addl_qual = " AND $addl_qual";
%    } else {
%      $addl_qual = " WHERE $addl_qual";
%    }
%  }
%
%  my $select;
%  if ( @select ) {
%    $select = 'cust_main.*, '. join (', ', @select);
%  } else {
%    $select = '*';
%  }
%
%  @cust_main = qsearch('cust_main', \%search, $select,   
%                         "$addl_qual $orderby $limit" );
%
%#  foreach my $cust_main ( @just_cust_main ) {
%#
%#    my @one_cust_main;
%#    $FS::Record::DEBUG=1;
%#    ( $cache, @one_cust_main ) = jsearch(
%#      "$monsterjoin",
%#      { 'custnum' => $cust_main->custnum },
%#      '',
%#      '',
%#      'cust_main',
%#      'custnum',
%#    );
%#    push @cust_main, @one_cust_main;
%#  }
%
%} else {
%  @cust_main=();
%  $sortby = \*last_sort;
%
%  push @cust_main, @{&custnumsearch}
%    if $cgi->param('custnum_on') && $cgi->param('custnum_text');
%  push @cust_main, @{&cardsearch}
%    if $cgi->param('card_on') && $cgi->param('card');
%  push @cust_main, @{&lastsearch}
%    if $cgi->param('last_on') && $cgi->param('last_text');
%  push @cust_main, @{&companysearch}
%    if $cgi->param('company_on') && $cgi->param('company_text');
%  push @cust_main, @{&address2search}
%    if $cgi->param('address2_on') && $cgi->param('address2_text');
%  push @cust_main, @{&phonesearch}
%    if $cgi->param('phone_on') && $cgi->param('phone_text');
%  push @cust_main, @{&referralsearch}
%    if $cgi->param('referral_custnum');
%
%  if ( $cgi->param('company_on') && $cgi->param('company_text') ) {
%    $sortby = \*company_sort;
%    push @cust_main, @{&companysearch};
%  }
%
%  if ( $cgi->param('search_cust') ) {
%    $sortby = \*company_sort;
%    $orderby = "ORDER BY LOWER(company || ' ' || last || ' ' || first )";
%    push @cust_main, smart_search( 'search' => $cgi->param('search_cust'),
%                                   'no_fuzzy_on_exact' => 1, #pref?
%                                 );
%  }
%
%  @cust_main = grep { $_->ncancelled_pkgs || ! $_->all_pkgs } @cust_main
%    if ! $cgi->param('cancelled')
%       && (
%         $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
%         || ( $conf->exists('hidecancelledcustomers')
%               && ! $cgi->param('showcancelledcustomers') )
%       );
%
%  my %saw = ();
%  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;
%}
%
%my %all_pkgs;
%if ( $conf->exists('hidecancelledpackages' ) ) {
%  %all_pkgs = map { $_->custnum => [ $_->ncancelled_pkgs ] } @cust_main;
%} else {
%  %all_pkgs = map { $_->custnum => [ $_->all_pkgs ] } @cust_main;
%}
%#%all_pkgs = ();
%
%if ( scalar(@cust_main) == 1 && ! $cgi->param('referral_custnum') ) {
%  if ( $cgi->param('quickpay') eq 'yes' ) {
%    print $cgi->redirect(popurl(2). "edit/cust_pay.cgi?quickpay=yes;custnum=". $cust_main[0]->custnum);
%  } else {
%    print $cgi->redirect(popurl(2). "view/cust_main.cgi?". $cust_main[0]->custnum);
%  }
%  #exit;
%} elsif ( scalar(@cust_main) == 0 ) {
%

<!-- mason kludge -->
%
%  errorpage("No matching customers found!");
%} else { 
%

<% include('/elements/header.html', "Customer Search Results", '' ) %>
% $total ||= scalar(@cust_main); 


  <% $total %> matching customers found

% my $pager = include( '/elements/pager.html',
%                        'offset'     => $offset,
%			 'num_rows'   => scalar(@cust_main),
%			 'total'      => $total,
%			 'maxrecords' => $maxrecords,
%                    );
%
%  unless ( $cgi->param('cancelled') ) {
%    if ( $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
%         || ( $conf->exists('hidecancelledcustomers')
%              && ! $cgi->param('showcancelledcustomers')
%            )
%       ) {
%      $cgi->param('showcancelledcustomers', 1);
%      $cgi->param('offset', 0);
%      print qq!( <a href="!. $cgi->self_url. qq!">show!;
%    } else {
%      $cgi->param('showcancelledcustomers', 0);
%      $cgi->param('offset', 0);
%      print qq!( <a href="!. $cgi->self_url. qq!">hide!;
%    }
%    print ' canceled customers</a> )';
%  }
%
%  if ( $cgi->param('referral_custnum') ) {
%    $cgi->param('referral_custnum') =~ /^(\d+)$/
%      or errorpage("Illegal referral_custnum");
%    my $referral_custnum = $1;
%    my $cust_main = qsearchs('cust_main', { custnum => $referral_custnum } );
%    print '<FORM METHOD="GET">'.
%          qq!<INPUT TYPE="hidden" NAME="referral_custnum" VALUE="$referral_custnum">!.
%          'referrals of <A HREF="'. popurl(2).
%          "view/cust_main.cgi?$referral_custnum\">$referral_custnum: ".
%          ( $cust_main->company
%            || $cust_main->last. ', '. $cust_main->first ).
%          '</A>';
%    print "\n",<<END;
%      <SCRIPT>
%      function changed(what) {
%        what.form.submit();
%      }
%      </SCRIPT>
%END
%    print ' <SELECT NAME="referral_depth" SIZE="1" onChange="changed(this)">';
%    my $max = 8; #config file
%    $cgi->param('referral_depth') =~ /^(\d*)$/ 
%      or errorpage("Illegal referral_depth");
%    my $referral_depth = $1;
%
%    foreach my $depth ( 1 .. $max ) {
%      print '<OPTION',
%            ' SELECTED'x($depth == $referral_depth),
%            ">$depth";
%    }
%    print "</SELECT> levels deep".
%          '<NOSCRIPT> <INPUT TYPE="submit" VALUE="change"></NOSCRIPT>'.
%          '</FORM>';
%  }
%
%  my @custom_priorities = ();
%  if ( $conf->config('ticket_system-custom_priority_field')
%       && @{[ $conf->config('ticket_system-custom_priority_field-values') ]} ) {
%    @custom_priorities =
%      $conf->config('ticket_system-custom_priority_field-values');
%  }
%
%  print "<BR><BR>". $pager. include('/elements/table-grid.html'). <<END;
%      <TR>
%        <TH CLASS="grid" BGCOLOR="#cccccc">#</TH>
%        <TH CLASS="grid" BGCOLOR="#cccccc">Status</TH>
%        <TH CLASS="grid" BGCOLOR="#cccccc">(bill) name</TH>
%        <TH CLASS="grid" BGCOLOR="#cccccc">company</TH>
%END
%
%if ( defined dbdef->table('cust_main')->column('ship_last') ) {
%  print <<END;
%      <TH CLASS="grid" BGCOLOR="#cccccc">(service) name</TH>
%      <TH CLASS="grid" BGCOLOR="#cccccc">company</TH>
%END
%}
%
%foreach my $addl_header ( @addl_headers ) {
%  print '<TH CLASS="grid" BGCOLOR="#cccccc">'. "$addl_header</TH>";
%}
%
%print <<END;
%        <TH CLASS="grid" BGCOLOR="#cccccc">Packages</TH>
%        <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=2>Services</TH>
%      </TR>
%END
%
%  my $bgcolor1 = '#eeeeee';
%  my $bgcolor2 = '#ffffff';
%  my $bgcolor;
%
%  my(%saw,$cust_main);
%  foreach $cust_main (
%    sort $sortby grep(!$saw{$_->custnum}++, @cust_main)
%  ) {
%
%    if ( $bgcolor eq $bgcolor1 ) {
%      $bgcolor = $bgcolor2;
%    } else {
%      $bgcolor = $bgcolor1;
%    }
%
%    my($custnum,$last,$first,$company)=(
%      $cust_main->custnum,
%      $cust_main->getfield('last'),
%      $cust_main->getfield('first'),
%      $cust_main->company,
%    );
%
%    my(@lol_cust_svc);
%    my($rowspan)=0;#scalar( @{$all_pkgs{$custnum}} );
%    foreach ( @{$all_pkgs{$custnum}} ) {
%      #my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
%      my @cust_svc = $_->cust_svc;
%      push @lol_cust_svc, \@cust_svc;
%      $rowspan += scalar(@cust_svc) || 1;
%    }
%
%    #my($rowspan) = scalar(@{$all_pkgs{$custnum}});
%    my $view;
%    if ( defined $cgi->param('quickpay') && $cgi->param('quickpay') eq 'yes' ) {
%      $view = $p. 'edit/cust_pay.cgi?quickpay=yes;custnum='. $custnum;
%    } else {
%      $view = $p. 'view/cust_main.cgi?'. $custnum;
%    }
%    my $pcompany = $company
%      ? qq!<A HREF="$view"><FONT SIZE=-1>$company</FONT></A>!
%      : '<FONT SIZE=-1>&nbsp;</FONT>';
%    
%    my $status = $cust_main->status;
%    my $statuscol = $cust_main->statuscolor;

    <TR>
      <TD CLASS="grid" ALIGN="right" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><A HREF="<% $view %>"><FONT SIZE=-1><% $cust_main->display_custnum %></FONT></A></TD>
      <TD CLASS="grid" ALIGN="center" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><FONT SIZE="-1" COLOR="#<% $statuscol %>"><B><% ucfirst($status) %></B></FONT></TD>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><A HREF="<% $view %>"><FONT SIZE=-1><% "$last, $first" %></FONT></A></TD>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><% $pcompany %></TD>
%
%    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
%      my($ship_last,$ship_first,$ship_company)=(
%        $cust_main->ship_last || $cust_main->getfield('last'),
%        $cust_main->ship_last ? $cust_main->ship_first : $cust_main->first,
%        $cust_main->ship_last ? $cust_main->ship_company : $cust_main->company,
%      );
%      my $pship_company = $ship_company
%        ? qq!<A HREF="$view"><FONT SIZE=-1>$ship_company</FONT></A>!
%        : '<FONT SIZE=-1>&nbsp;</FONT>';
%      


      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><A HREF="<% $view %>"><FONT SIZE=-1><% "$ship_last, $ship_first" %></FONT></A></TD>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %>><% $pship_company %></A></TD>
% }
%
%    foreach my $addl_col ( @addl_cols ) { 
% if ( $addl_col eq 'tickets' ) { 
% if ( @custom_priorities ) { 


             <TD CLASS="inv" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %> ALIGN=right><FONT SIZE=-1>

               <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>
% foreach my $priority ( @custom_priorities, '' ) { 
%
%                    my $num =
%                      FS::TicketSystem->num_customer_tickets($custnum,$priority);
%                    my $ahref = '';
%                    $ahref= '<A HREF="'.
%                            FS::TicketSystem->href_customer_tickets($custnum,$priority).
%                            '">'
%                      if $num;
%                 

        
                 <TR>
                   <TD ALIGN=right>
                     <FONT SIZE=-1><% $ahref.$num %></A></FONT>
                   </TD>
                   <TD ALIGN=left>
                     <FONT SIZE=-1><% $ahref %><% $priority || '<i>(none)</i>' %></A></FONT>
                   </TD>
                 </TR>
% } 


             <TR>
               <TH ALIGN=right STYLE="border-top: dashed 1px black">
               <FONT SIZE=-1>
% } else { 


          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %> ALIGN=right><FONT SIZE=-1>
% } 
%
%           my $ahref = '';
%           $ahref = '<A HREF="'.
%                       FS::TicketSystem->href_customer_tickets($custnum).
%                       '">'
%             if $cust_main->get($addl_col);
%        


        <% $ahref %><% $cust_main->get($addl_col) %></A>
% if ( @custom_priorities ) { 


          </FONT></TH>
            <TH ALIGN=left STYLE="border-top: dashed 1px black">
              <FONT SIZE=-1><% ${ahref} %>Total</A><FONT>
            </TH>
          </TR>
          </TABLE>
% } 


        </FONT></TD>
% } else { 


        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ROWSPAN=<% $rowspan || 1 %> ALIGN=right><FONT SIZE=-1>
          <% $cust_main->get($addl_col) %>
        </FONT></TD>
%
%      }
%    }
%
%    my($n1)='';
%    foreach ( @{$all_pkgs{$custnum}} ) {
%      my $pkgnum = $_->pkgnum;
%#      my $part_pkg = qsearchs( 'part_pkg', { pkgpart => $_->pkgpart } );
%      my $part_pkg = $_->part_pkg;
%
%      my $pkg_comment = $part_pkg->pkg_comment(nopkgpart => 1);
%      my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
%                   ? ''
%                   : ';show=packages';
%      my $frag = "cust_pkg$pkgnum"; #hack for IE ignoring real #fragment
%      my $pkgview = "${p}view/cust_main.cgi?custnum=$custnum$show;fragment=$frag#$frag";
%      my @cust_svc = @{shift @lol_cust_svc};
%      #my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
%      my $rowspan = scalar(@cust_svc) || 1;
%
%      print $n1, qq!<TD CLASS="grid" BGCOLOR="$bgcolor"  ROWSPAN=$rowspan><A HREF="$pkgview"><FONT SIZE=-1>$pkg_comment</FONT></A></TD>!;
%
%      my($n2)='';
%      foreach my $cust_svc ( @cust_svc ) {
%         my($label, $value, $svcdb) = $cust_svc->label;
%         my($svcnum) = $cust_svc->svcnum;
%         my($sview) = $p.'view';
%         print $n2,
%           qq!<TD CLASS="grid" BGCOLOR="$bgcolor" >!. FS::UI::Web::svc_link($m, $cust_svc->part_svc, $cust_svc) . qq!</TD> !.
%           qq!<TD CLASS="grid" BGCOLOR="$bgcolor" >!. FS::UI::Web::svc_label_link($m, $cust_svc->part_svc, $cust_svc) . qq!</TD> !;
%         $n2="</TR><TR>";
%      }
%
%      unless ( @cust_svc ) {
%        print qq!<TD CLASS="grid" BGCOLOR="$bgcolor" COLSPAN=2>&nbsp;</TD>!;
%      }
%
%      #print qq!</TR><TR>\n!;
%      $n1="</TR><TR>";
%    }
%
%    unless ( @{$all_pkgs{$custnum}} ) {
%      print qq!<TD CLASS="grid" BGCOLOR="$bgcolor" COLSPAN=3>&nbsp;</TD>!;
%    }
%    
%    print "</TR>";
%  }
%
%  

 
  </TABLE><% $pager %>

  <% include('/elements/footer.html') %>
% }
%
%#undef $cache; #does this help?
%
%#
%
%sub last_sort {
%  lc($a->getfield('last')) cmp lc($b->getfield('last'))
%  || lc($a->first) cmp lc($b->first);
%}
%
%sub company_sort {
%  return -1 if $a->company && ! $b->company;
%  return 1 if ! $a->company && $b->company;
%  lc($a->company) cmp lc($b->company)
%  || lc($a->getfield('last')) cmp lc($b->getfield('last'))
%  || lc($a->first) cmp lc($b->first);;
%}
%
%sub display_custnum_sort {
%  $a->display_custnum <=> $b->display_custnum;
%}
%
%sub custnum_sort {
%  $a->getfield('custnum') <=> $b->getfield('custnum');
%}
%
%sub tickets_sort {
%  $b->getfield('tickets') <=> $a->getfield('tickets');
%}
%
%sub custnumsearch {
%
%  my $custnum = $cgi->param('custnum_text');
%  $custnum =~ s/\D//g;
%  $custnum =~ /^(\d{1,23})$/ or errorpage("Illegal customer number");
%  $custnum = $1;
%  
%  [ qsearchs('cust_main', { 'custnum' => $custnum } ) ];
%}
%
%sub cardsearch {
%
%  my($card)=$cgi->param('card');
%  $card =~ s/\D//g;
%  $card =~ /^(\d{13,16})$/ or errorpage("Illegal card number");
%  my($payinfo)=$1;
%
%  [ qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'CARD'}),
%    qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'DCRD'})
%  ];
%}
%
%sub referralsearch {
%  $cgi->param('referral_custnum') =~ /^(\d+)$/
%    or errorpage("Illegal referral_custnum");
%  my $cust_main = qsearchs('cust_main', { 'custnum' => $1 } )
%    or errorpage("Customer $1 not found");
%  my $depth;
%  if ( $cgi->param('referral_depth') ) {
%    $cgi->param('referral_depth') =~ /^(\d+)$/
%      or errorpage("Illegal referral_depth");
%    $depth = $1;
%  } else {
%    $depth = 1;
%  }
%  [ $cust_main->referral_cust_main($depth) ];
%}
%
%sub lastsearch {
%  my(%last_type);
%  my @cust_main;
%  foreach ( $cgi->param('last_type') ) {
%    $last_type{$_}++;
%  }
%
%  $cgi->param('last_text') =~ /^([\w \,\.\-\']*)$/
%    or errorpage("Illegal last name");
%  my($last)=$1;
%
%  if ( $last_type{'Exact'} || $last_type{'Fuzzy'} ) {
%    push @cust_main, qsearch( 'cust_main',
%                              { 'last' => { 'op'    => 'ILIKE',
%                                            'value' => $last    } } );
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'ship_last' => { 'op'    => 'ILIKE',
%                                                 'value' => $last    } } )
%      if defined dbdef->table('cust_main')->column('ship_last');
%  }
%
%  if ( $last_type{'Substring'} || $last_type{'All'} ) {
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'last' => { 'op'    => 'ILIKE',
%                                            'value' => "%$last%" } } );
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'ship_last' => { 'op'    => 'ILIKE',
%                                                 'value' => "%$last%" } } )
%      if defined dbdef->table('cust_main')->column('ship_last');
%
%  }
%
%  if ( $last_type{'Fuzzy'} || $last_type{'All'} ) {
%    push @cust_main, FS::cust_main::Search->fuzzy_search( { 'last' => $last } );
%  }
%
%  #if ($last_type{'Sound-alike'}) {
%  #}
%
%  \@cust_main;
%}
%
%sub companysearch {
%
%  my(%company_type);
%  my @cust_main;
%  foreach ( $cgi->param('company_type') ) {
%    $company_type{$_}++ 
%  };
%
%  $cgi->param('company_text') =~
%    /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
%      or errorpage("Illegal company");
%  my $company = $1;
%
%  if ( $company_type{'Exact'} || $company_type{'Fuzzy'} ) {
%    push @cust_main, qsearch( 'cust_main',
%                              { 'company' => { 'op'    => 'ILIKE',
%                                               'value' => $company } } );
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'ship_company' => { 'op'    => 'ILIKE',
%                                                    'value' => $company } } )
%      if defined dbdef->table('cust_main')->column('ship_last');
%  }
%
%  if ( $company_type{'Substring'} || $company_type{'All'} ) {
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'company' => { 'op'    => 'ILIKE',
%                                               'value' => "%$company%" } } );
%
%    push @cust_main, qsearch( 'cust_main',
%                              { 'ship_company' => { 'op'    => 'ILIKE',
%                                                    'value' => "%$company%" } })
%      if defined dbdef->table('cust_main')->column('ship_last');
%
%  }
%
%  if ( $company_type{'Fuzzy'} || $company_type{'All'} ) {
%    push @cust_main, FS::cust_main::Search->fuzzy_search( { 'company' => $company } );
%  }
%
%  if ($company_type{'Sound-alike'}) {
%  }
%
%  \@cust_main;
%}
%
%sub address2search {
%  my @cust_main;
%
%  $cgi->param('address2_text') =~
%    /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
%      or errorpage("Illegal address2");
%  my $address2 = $1;
%
%  push @cust_main, qsearch( 'cust_main',
%                            { 'address2' => { 'op'    => 'ILIKE',
%                                              'value' => $address2 } } );
%  push @cust_main, qsearch( 'cust_main',
%                            { 'ship_address2' => { 'op'    => 'ILIKE',
%                                                   'value' => $address2 } } );
%
%  \@cust_main;
%}
%
%sub phonesearch {
%  my @cust_main;
%
%  my $phone = $cgi->param('phone_text');
%
%  #(no longer really) false laziness with Record::ut_phonen
%  #only works with US/CA numbers...
%  $phone =~ s/\D//g;
%  if ( $phone =~ /^(\d{3})(\d{3})(\d{4})(\d*)$/ ) {
%    $phone = "$1-$2-$3";
%    $phone .= " x$4" if $4;
%  } elsif ( $phone =~ /^(\d{3})(\d{4})$/ ) {
%    $phone = "$1-$2";
%  } elsif ( $phone =~ /^(\d{3,4})$/ ) {
%    $phone = $1;
%  } else {
%    errorpage(gettext('illegal_phone'). ": $phone");
%  }
%
%  my @fields = qw(daytime night fax);
%  push @fields, qw(ship_daytime ship_night ship_fax)
%    if defined dbdef->table('cust_main')->column('ship_last');
%
%  for my $field ( @fields ) {
%    push @cust_main, qsearch ( 'cust_main', 
%                               { $field => { 'op'    => 'LIKE',
%                                             'value' => "%$phone%" } } );
%  }
%
%  \@cust_main;
%}
