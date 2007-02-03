%die "access denied"
%  unless $FS::CurrentUser::CurrentUser->access_right('List services');
%
%my $conf = new FS::Conf;
%
%my @svc_broadband = ();
%my $sortby=\*svcnum_sort;
%if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {
%
%  @svc_broadband=qsearch('svc_broadband',{});
%
%  if ( $cgi->param('magic') eq 'unlinked' ) {
%    @svc_broadband = grep { qsearchs('cust_svc', {
%                                                   'svcnum' => $_->svcnum,
%                                                   'pkgnum' => '',
%                                                 }
%                                    )
%                          }
%		      @svc_broadband;
%  }
%
%  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
%    my $sortby = $1;
%    if ( $sortby eq 'blocknum' ) {
%      $sortby = \*blocknum_sort;
%    }
%  }
%
%} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
%
%  @svc_broadband =
%    qsearch( 'svc_broadband', {}, '',
%               " WHERE $1 = ( SELECT svcpart FROM cust_svc ".
%               "              WHERE cust_svc.svcnum = svc_external.svcnum ) "
%    );
%
%} elsif ( $cgi->param('ip_addr') =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
%  my $ip_addr = $1;
%  @svc_broadband = qsearchs('svc_broadband',{'ip_addr'=>$ip_addr});
%}
%
%my %routerbyblock = ();
%foreach my $router (qsearch('router', {})) {
%  foreach ($router->addr_block) {
%    $routerbyblock{$_->blocknum} = $router;
%  }
%}
%
%if ( scalar(@svc_broadband) == 1 ) {
%  print $cgi->redirect(popurl(2). "view/svc_broadband.cgi?". $svc_broadband[0]->svcnum);
%  #exit;
%} elsif ( scalar(@svc_broadband) == 0 ) {
%

<!-- mason kludge -->
%
%  eidiot "No matching ip address found!\n";
%} else {
%

<!-- mason kludge -->
%
%  my($total)=scalar(@svc_broadband);
%  print header("IP Address Search Results",''), <<END;
%
%    $total matching broadband services found
%    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
%      <TR>
%        <TH>Service #</TH>
%	<TH>Router</TH>
%        <TH>IP Address</TH>
%      </TR>
%END
%
%  foreach my $svc_broadband (
%    sort $sortby (@svc_broadband)
%  ) {
%    my($svcnum,$ip_addr,$routername,$routernum)=(
%      $svc_broadband->svcnum,
%      $svc_broadband->ip_addr,
%      $routerbyblock{$svc_broadband->blocknum}->routername,
%      $routerbyblock{$svc_broadband->blocknum}->routernum,
%    );
%
%    my $rowspan = 1;
%
%    print <<END;
%    <TR>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_broadband.cgi?$svcnum">$svcnum</A></TD>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/router.cgi?$routernum">$routername</A></TD>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_broadband.cgi?$svcnum">$ip_addr</A></TD>
%END
%
%    #print @rows;
%    print "</TR>";
%
%  }
% 
%  print <<END;
%    </TABLE>
%  </BODY>
%</HTML>
%END
%
%}
%
%sub svcnum_sort {
%  $a->getfield('svcnum') <=> $b->getfield('svcnum');
%}
%
%sub blocknum_sort {
%  if ($a->getfield('blocknum') == $b->getfield('blocknum')) {
%    $a->getfield('ip_addr') cmp $b->getfield('ip_addr');
%  } else {
%    $a->getfield('blocknum') cmp $b->getfield('blocknum');
%  }
%}
%
%
%

